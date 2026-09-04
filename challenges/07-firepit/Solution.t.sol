// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";

contract Firepit is Test {
    address user = vm.envAddress("USER_ADDRESS");
    address constant UNI = 0x57FB37d035e6Ad0E687E0a50dC3F515691deB815;
    address constant USDT = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68413600);
        vm.etch(0x4200000000000000000000000000000000000010, hex"60006000f3");
        deal(UNI, user, 2000e18);
    }

    function test_Solution() public {
        vm.startPrank(user);

        // your code
        //
        // UNIfication fee mechanism on X Layer:
        //   - The Uniswap V3 factory owner is the permissionless V3OpenFeeAdapter.
        //     Its collect((pool,amt0,amt1)[]) calls pool.collectProtocol(TOKEN_JAR, ...)
        //     for every listed pool, sweeping accrued protocol fees into the TokenJar.
        //   - The Firepit (ExchangeReleaser) then releases the WHOLE jar balance of the
        //     listed assets to us, in exchange for burning THRESHOLD = 2000 UNI (nonce 0).
        // So: collect the fat fee pools -> release USDT/USDG/WOKB to ourselves -> swap the
        // stable/WOKB legs to USDT. The fee jar holds ~25.6k USDT + ~21.3k USDG + ~134 WOKB
        // (~60.7k USDT once converted), far above the 45k USDT target.
        address firepit = 0xe122E231cb52aea99690963Fd73E91e33E97468f;
        address adapter = 0x6A88EF2e6511CAFfE2D006e260e7A5d1E7D4d7D7;
        address usdg = 0x4ae46a509F6b1D9056937BA4500cb143933D2dc8;
        address wokb = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
        address router = 0x4f0C28f5926AFDA16bf2506D5D9e57Ea190f9bcA;

        // 1) hand the Firepit its 2000 UNI toll for the single release
        IERC20(UNI).approve(firepit, 2000e18);

        // 2) sweep protocol fees from the highest-value pools into the TokenJar.
        //    amount0/amount1 = uint128 max => collect the full protocol-fee balance.
        {
            address[10] memory pools = [
                0x63d62734847E55A266FCa4219A9aD0a02D5F6e02, // USDT/WOKB   0.30%
                0xe1071DB4691b325c709854DC3D5CcD5d77e62Ed1, // USDG/wTSLAx 0.05%
                0xe3BE6A0137f1b0602Fc1a4841686f43B340a5082, // USDT/WOKB   0.05%
                0x0cBe0dBE1400e57f371a38BD3b9bC80F7C3676dA, // USDG/USDT   0.01%
                0x77ef18adF35f62B2Ad442e4370cDbC7fe78B7dcC, // USDT/xETH   0.05%
                0x4651300221f345a4c6F566079BD1DDC291049c7d, // xSOL/USDT   0.05%
                0x2a2B11730C2b6d99a58034A869dd810D7300a7b2, // USDG/wNVDAx 0.05%
                0x5fcFb33C9AB1665FeE892eB2aF163e863a874D73, // USDT/xBTC   0.05%
                0xc44bd9c8589026D28D1632d7b86b2Efb6cDc8fd2, // USDG/wAAPLx 0.05%
                0x9e485CC2Ec10E87A9B6e58602889Df392B7F6453  // USDT/WOKB   0.01%
            ];
            // collect((address,uint128,uint128)[]) — selector via encodeWithSignature,
            // then the dynamic array (offset, length, then one 96-byte struct per pool).
            bytes memory cd = abi.encodeWithSignature("collect((address,uint128,uint128)[])");
            cd = bytes.concat(cd, abi.encode(uint256(0x20), pools.length));
            for (uint256 i = 0; i < pools.length; i++) {
                cd = bytes.concat(cd, abi.encode(pools[i], type(uint128).max, type(uint128).max));
            }
            (bool success,) = adapter.call(cd);
            require(success, "collect failed");
        }

        // 3) release the jar's full USDT / USDG / WOKB balances to us (burns the 2000 UNI)
        {
            address[] memory assets = new address[](3);
            assets[0] = USDT;
            assets[1] = usdg;
            assets[2] = wokb;
            (bool success,) =
                firepit.call(abi.encodeWithSignature("release(uint256,address[],address)", uint256(0), assets, user));
            require(success, "release failed");

            // console.log("released from jar - USDT: %6e", IERC20(USDT).balanceOf(user));
            // console.log("released from jar - USDG: %6e", IERC20(usdg).balanceOf(user));
            // console.log("released from jar - WOKB: %18e", IERC20(wokb).balanceOf(user));
        }

        // 4) convert the non-USDT legs to USDT via SwapRouter02.exactInputSingle
        {
            uint256 usdgAmount = IERC20(usdg).balanceOf(user);
            IERC20(usdg).approve(router, usdgAmount);
            (bool success,) = router.call(
                abi.encodeWithSignature(
                    "exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))",
                    usdg, USDT, uint24(100), user, usdgAmount, uint256(0), uint160(0)
                )
            );
            require(success, "swap usdg failed");
            // console.log("swapped USDG in: %6e", usdgAmount);
            // console.log("USDT after USDG swap: %6e", IERC20(USDT).balanceOf(user));
        }
        {
            uint256 wokbAmount = IERC20(wokb).balanceOf(user);
            IERC20(wokb).approve(router, wokbAmount);
            (bool success,) = router.call(
                abi.encodeWithSignature(
                    "exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))",
                    wokb, USDT, uint24(500), user, wokbAmount, uint256(0), uint160(0)
                )
            );
            require(success, "swap wokb failed");
            // console.log("swapped WOKB in: %18e", wokbAmount);
            // console.log("USDT after WOKB swap: %6e", IERC20(USDT).balanceOf(user));
        }

        vm.stopPrank();
        checkSolve();
    }

    function checkSolve() public view {
        require(IERC20(USDT).balanceOf(user) >= 45_000e6, "not enough USDT");
        console.log("Firepit solved. USDT: %6e", IERC20(USDT).balanceOf(user));
    }
}
