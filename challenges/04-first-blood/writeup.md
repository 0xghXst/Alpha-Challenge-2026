# 04 — First Blood

The Solana $TRUMP launch poses two questions: the first attempt to snipe the token, and the transaction that actually opened trading. Both answers are Solana signatures, and the grader compares `sha256(signature.lower())`, so any candidate can be confirmed by hashing it directly.

The market is a Meteora DLMM `TRUMP/USDC` pair (`A8nPhpCJqtqHdqUk35Uj9Hy2YsGXFkCZGuNwvkD3k7VC`). Trading is gated by the pair's `pair_status`, which starts disabled and is later turned on by a `TogglePairStatus` transaction — that toggle is `trading_possible`. The first snipe attempt comes before it, from a bot probing the pool while it is still closed.

Reconstructing the launch timeline is the first obstacle: the mint is too active to paginate back to genesis, since `getSignaturesForAddress` returns newest-first only. The workaround is to anchor on a low-activity account — roughly 80% of supply sits in a Magna lockup with only a few hundred transactions, so its oldest signature lands at the launch-setup moment. Reusing that signature as the mint's `before` cursor isolates the ~30 deployer setup transactions. The sequence is then clear: mint created around 14:00 UTC, supply minted, authorities burned, LB pair created at 14:19, liquidity seeded, and the pair left disabled.

**first_snipe:** At 22:05:52 the wallet `8QxqUZ…` calls a custom sniper program. The transaction succeeds but buys nothing: it logs `NS` (the bot's "not started, skip the swap" marker), never calls the DLMM swap, and moves only a dust amount of SOL. Token balances are unchanged — the wallet holds 257,656 USDC ready to buy, but `pair_status` is still disabled, so the bot exits early. This is the first attempt to snipe: fully funded and probing the pool four hours before launch, eighteen minutes ahead of the first actual (failing) swap.

```
first_snipe = 41h3CuLHamSdfsmgWC887eoyvrTiUcGjhLZpKMeqE9Rg9ZkP42C2gBr5PrQM9D25jRFwwQYPfBUJYCEUXC1qAxcv
```

**trading_possible:** Swaps fail with error 6042 (`PoolDisabled`) until the pair is enabled. Scanning the seconds before the first *successful* swap (02:01:49) locates it: at 02:01:32 the authority `5unTfT2…` runs `TogglePairStatus`, flipping the pair from disabled to enabled.

```
trading_possible = 4SMUTho76nrPXxGNdDBNdBNbtbSC48oDDkivVKSdWUJR8KZGQwv1tEwJnHFXmpFDFkkLRupzzW28e6HHpv49afQt
```
