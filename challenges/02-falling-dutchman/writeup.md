# 02 — Falling Dutchman

The task: step into DutchX — Gnosis's old Dutch-auction DEX — at block 9462777 back in 2020, and turn 0.1 ETH into at least 4.

The thing that makes DutchX exploitable here is that it doesn't run one auction per pair, it runs two facing opposite directions, sharing a single index. For KNC/WETH at index 1051, one auction is selling KNC for WETH and the other is selling WETH for KNC. In a Dutch auction the price starts high and falls, and at this block both sides have been running about 23 hours with nobody buying. Both prices have decayed to roughly 2.3% of fair value — a ~43× discount against the previous close. So both auctions are sitting full:

- auction A holding **2,820.7 KNC**
- auction B holding **4.482 WETH**

(The two amounts match at the fair price of ~0.001589 WETH/KNC, which is the tell that the maker seeded both sides equally and that price is real.)

Clearing an auction as its sole buyer costs only DutchX's ~0.5% liquidity fee and returns almost the entire sell volume, so the 0.1 ETH seed is enough to drain both auctions in sequence:

1. Wrap the 0.1 ETH and deposit it into DutchX, then buy KNC cheap in auction A (a partial fill).
2. Spend ~65 of that KNC to *clear* auction B and take all 4.482 WETH.
3. Feed that WETH back to *clear* auction A and take the rest of the KNC.
4. Withdraw everything and dump the KNC on Kyber for native ETH.

Passing `type(uint256).max` as the buy amount lets each clear auto-cap to whatever volume is left, so there are no exact figures to compute. The run ends with 8.85 ETH.
