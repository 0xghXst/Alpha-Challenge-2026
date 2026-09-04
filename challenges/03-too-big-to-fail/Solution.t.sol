// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";
import "./Interfaces.sol";
import "./Constants.sol";

contract TooBigToFail is Test {
    address user = vm.envAddress("USER_ADDRESS");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK);
        vm.deal(user, 0.1 ether);
    }

    function test_Solution() public {
        vm.startBroadcast(user);
        // Your solution goes here.
        //
        // Liquity's PriceFeed stores a stale lastGoodPrice ($2096), under which
        // this $1B Trove looks safe (ICR 141%, system TCR 153% -> not Recovery).
        // But liquidate() calls fetchPrice() first, refreshing to the real
        // Chainlink price ($1976). At that price the system TCR drops to 145%,
        // flipping Liquity into Recovery Mode, where any Trove with ICR < TCR is
        // liquidatable -- and this one sits at 133%. Bots keyed off the stored
        // price never saw it. The Stability Pool (1.08B LUSD) absorbs the 900M
        // debt, and we, as the liquidator, receive the collateral gas
        // compensation: 0.5% of the seized collateral ~= 2504 ETH, in ETH.
        address troveManager = 0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2;
        address borrower = 0x903d12bf2c57A29f32365917c706ce0e1a84Cce3;

        (bool success,) = troveManager.call(abi.encodeWithSignature("liquidate(address)", borrower));
        require(success, "liquidate failed");

        // console.log("liquidation reward: %18e ETH", user.balance);
        vm.stopBroadcast();
        checkSolve();
    }

    function checkSolve() public view {
        require(user.balance >= 2500 ether, "not enough ETH");
        console.log("Solved. Ending balance in ETH: %18e", user.balance);
    }
}
