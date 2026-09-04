// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import "../../src/Interfaces.sol";
import "./Interfaces.sol";
import "./Constants.sol";

contract ColdStart is Test {
    address user = vm.envAddress("USER_ADDRESS");

    uint256 l1Fork;
    uint256 l2Fork;
    address constant ROLLUP = 0x23A19d23e89166adedbDcB432518AB01e4272D94;
    bool relayed;

    function setUp() public {
        l1Fork = vm.createFork(vm.envString("ETH_RPC_URL"), L1_FORK_BLOCK);
        string memory l2url = vm.envOr("ROBINHOOD_RPC_URL", string(""));
        require(bytes(l2url).length > 0, "set ROBINHOOD_RPC_URL in .env");
        l2Fork = vm.createFork(l2url, L2_FORK_BLOCK);

        vm.selectFork(l1Fork);
        vm.deal(user, 10 ether);
        vm.prank(ROLLUP);
        IInbox(INBOX).setAllowListEnabled(false);
    }

    function test_Solution() public {
        vm.selectFork(l1Fork);
        vm.recordLogs();
        vm.startBroadcast(user);

        // your code
        //
        // Only entry point to the L2 is the L1 Delayed Inbox. Each retryable ticket
        // we post is later run on the L2 by _relay() as our aliased address
        // (user + 0x1111..1111): to.call{value: l2CallValue}(data), l2CallValue
        // funded for free on the L2. CASHCAT lives in a Uniswap-V3-style pool
        // (CASHCAT/WETH, 1% fee) reachable via SwapRouter02. Post three L1->L2
        // messages our alias runs on the L2: wrap ETH->WETH, approve router, then
        // exactInputSingle with recipient = `user` (the balance-check target).
        // (all logic kept inside this block; split into scopes to avoid stack-too-deep)
        address weth = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;   // WETH on the L2
        address router = 0xCaf681a66D020601342297493863E78C959E5cb2; // Uniswap SwapRouter02
        uint24 poolFee = 10000;                                      // CASHCAT/WETH pool: 1%

        // 1) wrap 1 ETH -> WETH on the L2 (alias becomes the WETH holder)
        {
            (bool success,) = INBOX.call{value: 1.012 ether}(
                abi.encodeWithSignature(
                    "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                    weth,
                    uint256(1 ether),
                    uint256(0.01 ether),
                    user,
                    user,
                    uint256(2_000_000),
                    uint256(1 gwei),
                    abi.encodeWithSignature("deposit()")
                )
            );
            require(success, "ticket1(wrap) failed");
        }

        // 2) approve SwapRouter02 to spend the alias's WETH
        {
            (bool success,) = INBOX.call{value: 0.012 ether}(
                abi.encodeWithSignature(
                    "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                    weth,
                    uint256(0),
                    uint256(0.01 ether),
                    user,
                    user,
                    uint256(2_000_000),
                    uint256(1 gwei),
                    abi.encodeWithSignature("approve(address,uint256)", router, type(uint256).max)
                )
            );
            require(success, "ticket2(approve) failed");
        }

        // 3) swap WETH -> CASHCAT via exactInputSingle, sending CASHCAT to `user`
        //    params tuple: (tokenIn, tokenOut, fee, recipient, amountIn, amountOutMin, sqrtPriceLimit)
        {
            bytes memory swapCd = abi.encodePacked(
                bytes4(0x04e45aaf),
                abi.encode(weth, CASHCAT, poolFee, user, uint256(1 ether), uint256(1_000_000e18), uint160(0))
            );
            (bool success,) = INBOX.call{value: 0.012 ether}(
                abi.encodeWithSignature(
                    "createRetryableTicket(address,uint256,uint256,address,address,uint256,uint256,bytes)",
                    router,
                    uint256(0),
                    uint256(0.01 ether),
                    user,
                    user,
                    uint256(2_000_000),
                    uint256(1 gwei),
                    swapCd
                )
            );
            require(success, "ticket3(swap) failed");
        }

        vm.stopBroadcast();

        _relay();
        checkSolve();
    }

    // Executes every L1->L2 message you posted, on the L2, as your aliased
    // address, standing in for the sequencer. Do not edit.
    function _relay() internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        address alias_ = address(uint160(user) + uint160(0x1111000000000000000000000000000000001111));
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != INBOX) continue;
            bytes memory m = abi.decode(logs[i].data, (bytes));
            if (m.length < 288) continue;
            address to = address(uint160(_word(m, 0)));
            uint256 l2CallValue = _word(m, 1);
            uint256 len = _word(m, 8);
            bytes memory cd = new bytes(len);
            for (uint256 k = 0; k < len; k++) cd[k] = m[288 + k];

            vm.selectFork(l2Fork);
            vm.deal(alias_, alias_.balance + l2CallValue);
            vm.prank(alias_);
            (bool ok,) = to.call{value: l2CallValue}(cd);
            ok;
            relayed = true;
        }
    }

    function checkSolve() public view {
        require(relayed, "you never posted a message to the inbox");
        require(IERC20(CASHCAT).balanceOf(user) >= 1_000_000e18, "not enough CASHCAT");
        console.log("Cold Start solved. CASHCAT: %18e", IERC20(CASHCAT).balanceOf(user));
    }

    function _word(bytes memory m, uint256 i) private pure returns (uint256 v) {
        assembly {
            v := mload(add(add(m, 32), mul(i, 32)))
        }
    }
}
