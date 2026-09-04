# 01 — Out of Nowhere

Find the source-chain transaction behind a $1.5M USDC inflow on Ethereum.

The receiving Ethereum tx (`0xe7b8d46c…`) calls `0xbbbd1bbb4f9b936c3604906d7592a644071de884` = **Allbridge: Bridge**, method `unlock`:

```
unlock(uint128 lockId, address recipient, uint256 amount,
       bytes4 lockSource, bytes4 tokenSource, bytes32 tokenSourceAddress, bytes signature)
```

Allbridge Classic locks tokens on one chain and unlocks the equivalent on another, so the unlock args point straight at the source:

- `lockSource = 0x53544b5a` = `"STKZ"` = the **Stacks** blockchain (a non-EVM Bitcoin L2, which is why the source tx isn't on any EVM chain).
- `lockId = 0x0159fa4cd496a40b6531521bb9138a06` identifies the transfer.

On Stacks (Hiro API), the matching `lock` with that id is `origin_tx`:

```
contract  SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.bridge
function  lock
lock-id   0x0159fa4cd496a40b6531521bb9138a06   ← same id as the Ethereum unlock
amount    u1500000000000                        (1,500,000 aeUSDC; 1,498,500 lands after the ~0.1% fee)
recipient 0xec5f…994b
dest      0x45544800  ("ETH")
```

The shared lock-id ties the Stacks `lock` and the Ethereum `unlock` together as the two halves of one transfer.

```
origin_tx = 0x36f2d5c245d08de980d0d23e4bd23b088312ce9e4b9845b4fd71930f52aab8fc
```
