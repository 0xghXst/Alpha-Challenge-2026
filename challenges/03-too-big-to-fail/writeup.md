# 03 — Too Big To Fail

During the May 19, 2021 crash, liquidators cleared positions across the market within seconds, yet one $1B Liquity Trove stayed untouched long enough for its owner to rebalance out of danger. The task is to process that liquidation at block 12465029 and finish with more than 2,500 ETH.

The reason the bots missed it is a stale price. Liquity's `PriceFeed` caches a `lastGoodPrice`, which at this block is $2,096. At $2,096 the Trove looks safe — ICR ~141%, and system-wide TCR at 153%, above the 150% CCR — so the protocol reads as Normal Mode with nothing improperly liquidatable. A bot keying off the stored price sees no opportunity.

But `liquidate()` does not use the cached value. It calls `fetchPrice()` first, refreshing to the live Chainlink price of $1,976. At the true price the system TCR drops to ~145%, below the 150% CCR, and Liquity enters **Recovery Mode**, where any Trove with ICR below the TCR becomes liquidatable — and this one sits at ~133%. The position therefore only becomes liquidatable *within the transaction*, after the price refresh, which is exactly why bots watching the stale value never fired.

(ICR is a single Trove's collateral-to-debt ratio; TCR is the same measure system-wide; CCR is the 150% threshold that triggers Recovery Mode; MCR, the Normal-Mode floor, is 110%.)

The solve is a single call:

```solidity
(bool success,) = troveManager.call(abi.encodeWithSignature("liquidate(address)", borrower));
```

No capital is required beyond gas: the Stability Pool (1.08B LUSD) absorbs the ~900M of debt, and as the liquidator I receive the collateral gas compensation — 0.5% of the seized collateral, paid in ETH. The run ends with 2504.48 ETH.
