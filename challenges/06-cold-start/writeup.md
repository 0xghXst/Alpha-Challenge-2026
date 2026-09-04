# 06 — Cold Start

A new Arbitrum-style L2 (Robinhood Chain) has just launched with an early token, CASHCAT, but the chain has no public RPC, bridge front-end, or explorer — the only reachable entry point is the L1 Delayed Inbox. The task is to make the L2 address hold at least 1,000,000 CASHCAT.

The harness defines the constraints. The test forks both chains. Anything posted to the L1 Inbox is picked up by `_relay()` (standing in for the sequencer) and executed on the L2 under the *aliased* address `user + 0x1111000000000000000000000000000000001111`, not `user` — the offset Arbitrum applies to an L1 sender when its message lands on L2. The relayer parses each message in the format `createRetryableTicket` produces, credits the L2 call value, and runs `to.call{value}(data)`.

The solve scripts the L2-side purchase as retryable tickets posted from L1. CASHCAT trades in a Uniswap-V3-style CASHCAT/WETH pool (1% fee) reachable through SwapRouter02, so three messages suffice:

1. A ticket to WETH carrying 1 ETH of call value with `deposit()` — the alias now holds WETH on L2.
2. A ticket to WETH with `approve(SwapRouter02, max)`.
3. A ticket to SwapRouter02 with `exactInputSingle((WETH, CASHCAT, 10000, user, 1e18, minOut, 0))`.

Because the alias executes on L2, it is the alias that holds the WETH and performs the approve and swap, while the balance check reads `user`. Setting the swap's `recipient = user` delivers the CASHCAT to the checked address. Each ticket carries a small amount of extra ETH for the L2 call value and submission cost. The run ends with ~5.98M CASHCAT.
