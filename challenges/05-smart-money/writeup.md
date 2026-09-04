# 05 — Smart Money

Put a name to four Ethereum addresses:

```
protocol_one = C3 Protocol     (fundraise at 0xAf09…Dc95)
investor_one = Node Capital     (VC at 0xC29A…8C1f)
protocol_two = Aligned Layer    (fundraise at 0xe53e…AC8f)
company      = Bridge           (high-volume 0x4c2c…00B8)
```

`company` is direct: `0x4c2c` is tagged "Bridge.xyz" on Etherscan → **Bridge**.

The other three are resolved by tracing to a confirmed counterparty, pinning the fundraising round through a fundraising database, and hash-verifying the exact name, since the grader compares `sha256(normalized name)`:

- **protocol_one / investor_one** — a confirmed investor into `0xAf09` is Arrington XRP Capital, so the wallet is one round in Arrington's 2021 portfolio; hashing candidates from that portfolio yields **C3 Protocol**. `0xC29A` is then one of C3's investors, and hashing down C3's investor list yields **Node Capital**.
- **protocol_two** — funds out of `0xe53e` go to LambdaClass, so the raise is one of their projects: a 2024 Ethereum infrastructure company from the LambdaClass team that raised over $20M, which hashes to **Aligned Layer**.
