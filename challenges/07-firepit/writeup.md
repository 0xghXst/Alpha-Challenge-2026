# 07 — Firepit

Uniswap's "UNIfication" turned on protocol fees, allowing searchers to burn UNI and release the accumulated fees to themselves. The challenge provides 2,000 UNI on X Layer at block 68413600, with the goal of finishing with at least 45,000 USD₮0.

The setup involves three contracts, all verified on-chain. The V3 factory's owner is a permissionless `V3OpenFeeAdapter`, whose `collect((pool,amt0,amt1)[])` calls `collectProtocol(TOKEN_JAR, ...)` on each listed pool, sweeping accrued protocol fees into a `TokenJar`. The Firepit (an `ExchangeReleaser`) then releases the jar's balance of the named assets in exchange for burning exactly 2,000 UNI (nonce 0); `TokenJar.release` sends the *full* balance of each listed asset. Since the harness provides exactly 2,000 UNI, this permits a single release of up to 20 assets. (`_afterRelease` bridges the burned UNI to `0xdead` through the L2 standard bridge at `0x4200…0010`, which the harness `vm.etch`es to a no-op so the release does not revert.)

The difficulty is not the mechanism but locating enough fees. The obvious USDT/WOKB pairs hold only about $25k, short of 45. Enumerating every pool with protocol fees enabled — via the adapter's `FeeUpdateTriggered` events, 4,981 pools — and reading each `protocolFees()` at the fork block surfaces the real source: **25,482 USDG** (Global Dollar, a dollar stablecoin) spread across US-stock token pairs such as USDG/wTSLAx and USDG/wNVDAx. USDT (26,570), USDG (25,482), and a small amount of WOKB (142) together are more than enough.

One caveat when valuing the pools: the xETH / xBTC / xSOL fees sit in mirror pools where the reserve equals the protocol fee — there is no real liquidity behind them, so those tokens can be collected but not sold, and are excluded.

The solve is four steps:

1. `UNI.approve(firepit, 2000e18)`.
2. `collect` on the ten richest fee pools with `uint128.max` on both sides, sweeping USDT + USDG + WOKB into the jar.
3. `release(0, [USDT, USDG, WOKB], user)` — burns the 2,000 UNI and sends all three assets to me.
4. Swap USDG→USDT and WOKB→USDT through SwapRouter02.

Calls are built with `abi.encodeWithSignature`, and `collect`'s dynamic struct array is assembled with `bytes.concat`. USDG alone already clears 45k; WOKB is margin. The run ends with 60,702 USDT.
