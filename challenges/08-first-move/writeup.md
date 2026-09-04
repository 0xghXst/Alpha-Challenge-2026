# 08 — First Move

Two OP Stack fault dispute games are created on L1, one for Ink and one for Optimism, both with the bogus root claim `0xdeadbeef…`. For each, find the correct `bytes32` to submit as the first attack on that root, `attack(rootClaim, 0, claim)`.

```
ink_claim = 0x82c941153a9de14c4533b301799ee33206b6a475d7c4fdbe7cd2f1c9d7271b6f
op_claim  = 0x192f163548d61d555a282e1ffcec8ec7b1e4cf9deced7e910b87292f0aeab5f1
```

A fault dispute game bisects an L2 output root down a binary tree. Attacking the root moves to tree position gindex 2, depth 1, and the honest counter-claim there is the correct output root of the L2 block that position disputes:

```
output root = keccak256(abi.encode(0, stateRoot, L2ToL1MessagePasser storageRoot, blockHash))
```

Game type 8 is a standard `FaultDisputeGame` v2.4.2 (confirmed via `gameImpls(8)`). From its source, the disputed block for the first attack is `startingBlockNumber + traceIndex(gindex2, splitDepth=30) + 1`, clamped to `l2BlockNumber` — i.e. `startingBlockNumber + 2^29`: block 589,830,147 for Ink and 692,317,405 for Optimism.

Both are far beyond the real chain tip. These are malformed spam games: the `l2BlockNumber` field (1787098259) is the L1 creation-block timestamp, and the range it implies (~1.6B) exceeds the tree's 2^30 capacity. An honest challenger (op-program) can only derive L2 state up to `l1Head` (L1 block 25785478), so when the disputed block is beyond what is derivable, the honest answer is the output root of each chain's safe head at `l1Head`.

The safe head is not the anchor block or the L1-origin boundary; it sits slightly below the boundary, since batches are posted with a delay. With the answer hash given, I validated the output-root formula against a real game's `startingRootHash` (exact match), then searched downward from the boundary, computing each block's output root and matching the target hash. This gives Optimism block 155,749,670 and Ink block 53,599,386.
