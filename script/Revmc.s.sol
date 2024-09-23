// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

contract RevmcScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Create a new contract with the specified bytecode
        address newContract = address(new ContractWithSpecificCode());

        console.log("Contract deployed at:", newContract);

        vm.stopBroadcast();
    }
}

contract ContractWithSpecificCode {
    constructor() {
        // return blob hash of 0x99b800
        //bytes memory code = hex"6299b800495f5260205ff3";

        // return blob hash of 0
        // bytes memory code = hex"5f495f5260205ff3";

        // if (blob hash of 0) >> calldata[4] is 1 then revert, otherwise return 1
        bytes
            memory code = hex"5f496004351c60011660145760015f5260205ff35b5f5ffd";

        // if blob hash of 0 = 0, revert
        // bytes memory code = hex"5f495f14600f5760015f5260205ff35b5f5ffd";

        // if blob hash of 0 least sig bit = 1, revert, otherwise return 1
        // bytes memory code = hex"5f4960011660105760015f5260205ff35b5f5ffd";

        // if chain id > 100000 then revert, otherwise return chain id
        // bytes memory code = hex"46620186A010601057465f5260205ff35b5f5ffd";
        // if chain id > 100 then revert, otherwise return chain id
        // bytes memory code = hex"46606410600e57465f5260205ff35b5f5ffd";
        // if chain id = 31337 then revert, otherwise return chain id
        // bytes memory code = hex"46617a6914600f57465f5260205ff35b5f5ffd";
        assembly {
            return(add(code, 0x20), mload(code))
        }
    }
}
