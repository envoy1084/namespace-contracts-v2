# Module Catalog

Namespace modules are activation-scoped and configured by the controller.

Current module kinds:

| Kind | Interface | Purpose |
| --- | --- | --- |
| Rule | `IRuleModule` | Eligibility, gating, pricing, discounts, overrides. |
| Payment | `IPaymentModule` | Collect final payment from the payer. |
| Post hook | `IPostHookModule` | Run after registry mint or renewal. |

## Rules

Rules share the same output shape:

```solidity
struct RuleOutput {
    Decision decision;
    PriceOp priceOp;
    uint16 bps;
    address token;
    uint256 amount;
    uint256 addFlags;
    uint256 requireFlags;
}
```

The controller accepts `PriceOp.NONE` from any phase. Every non-`NONE` price operation must match the configured rule phase:

| Phase | Allowed non-`NONE` price ops |
| --- | --- |
| `GUARD` | none |
| `ELIGIBILITY` | none |
| `BASE_PRICE` | `SET_BASE` |
| `PREMIUM` | `ADD`, `MARKUP_BPS`, `MIN` |
| `DISCOUNT` | `SUBTRACT`, `DISCOUNT_BPS`, `MAX` |
| `OVERRIDE` | `OVERRIDE` |
| `FINAL_CHECK` | `MIN`, `MAX` |

Rules that can emit several price operations are reusable, but each activation instance must be placed in the phase matching the operation that runtime claims will emit.

### PauseRule

Purpose: activation-owner pause switch.

Configuration: none.

Owner action:

```solidity
pauseRule.setPaused(activationId, true);
pauseRule.setPaused(activationId, false);
```

Use it in `GUARD` phase so paused activations fail before expensive proof or pricing rules.

### SaleWindowRule

Purpose: allow mint/renew only inside a time window.

```solidity
SaleWindowRule.Params({
    startTime: uint64(...),
    endTime: uint64(...)
})
```

Use `0` to disable either bound.

### LabelLengthRule

Purpose: enforce byte-length bounds.

```solidity
LabelLengthRule.Params({
    minLength: 3,
    maxLength: 12
})
```

This intentionally checks byte length. UI/off-chain services should handle ENS normalization and grapheme-aware validation before users sign or submit transactions.

### TokenBalanceRule

Purpose: ERC20 token gate and optional discount.

```solidity
TokenBalanceRule.Params({
    token: ERC20(address(token)),
    minBalance: 100 ether,
    discountBps: 500
})
```

Use as:

| Mode | Params |
| --- | --- |
| Gate only | `minBalance > 0`, `discountBps = 0` |
| Discount only | `minBalance = 0`, `discountBps > 0` |
| Gate plus discount | both set |

If the rule applies a discount, place it in `DISCOUNT` phase so it runs after base price and premiums.

### FixedPriceRule

Purpose: set a fixed base price with optional exact byte-length overrides.

```solidity
FixedPriceRule.Params({
    token: address(usdc),
    defaultMintAmount: 100e6,
    defaultRenewAmount: 50e6,
    lengthPrices: exactLengthPrices
})
```

Output:

```text
PriceOp.SET_BASE
```

Use in `BASE_PRICE` phase.

### LengthPremiumRule

Purpose: add per-second premiums by label byte length.

```solidity
LengthPremiumRule.Params({
    token: address(usdc),
    mintPricePerSecondByLength: mintRates,
    renewPricePerSecondByLength: renewRates
})
```

Index `0` prices one-byte labels. Labels longer than the table use the final bucket.

Output:

```text
PriceOp.ADD
```

Use in `PREMIUM` phase.

### LabelClassRule

Purpose: match number, letter, or emoji-only labels and optionally price or block non-matches.

```solidity
LabelClassRule.Params({
    token: address(usdc),
    labelClass: LabelClassRule.LabelClass.NUMBER,
    requireMatch: true,
    mintAmount: 500e6,
    renewAmount: 100e6,
    priceOp: NamespaceTypes.PriceOp.ADD
})
```

Examples:

| Goal | Config |
| --- | --- |
| Only number labels | `labelClass = NUMBER`, `requireMatch = true`, `priceOp = NONE` |
| Emoji premium | `labelClass = EMOJI`, `requireMatch = false`, `priceOp = ADD` |
| Letter-only sale | `labelClass = LETTER`, `requireMatch = true` |

Use it in `ELIGIBILITY` when `priceOp = NONE`, `BASE_PRICE` when `priceOp = SET_BASE`, `PREMIUM` when `priceOp = ADD`, or `OVERRIDE` when `priceOp = OVERRIDE`.

### USDOracleRule

Purpose: convert USD-denominated mint/renew prices into token amounts through a Chainlink-compatible token/USD oracle.

```solidity
USDOracleRule.Params({
    token: address(token),
    oracle: IAggregatorV3(address(oracle)),
    tokenDecimals: 18,
    maxStaleness: 1 days,
    mintUsdPrice: 100e18,
    renewUsdPrice: 25e18,
    priceOp: NamespaceTypes.PriceOp.SET_BASE
})
```

Use `SET_BASE` in `BASE_PRICE` for a USD base price, `ADD` in `PREMIUM` for a USD premium, or `OVERRIDE` in `OVERRIDE` for an exact USD-denominated special price. The rule rejects stale, invalid, or incomplete oracle rounds.

Production constraints:

- `maxStaleness` must be non-zero. Oracle freshness cannot be disabled.
- `tokenDecimals` must be 18 or lower.
- the oracle's own `decimals()` value must be 18 or lower.

### ReservationRule

Purpose: claim-based reserved label behavior.

```solidity
ReservationRule.Params({
    root: reservationRoot
})
```

Runtime claim:

```solidity
ReservationRule.Claim({
    labelHash: labelHash,
    account: reservedBuyer,
    startTime: start,
    endTime: end,
    mintable: true,
    token: address(usdc),
    mintPrice: 1000e6,
    renewPrice: 100e6,
    priceOp: NamespaceTypes.PriceOp.OVERRIDE,
    proof: proof
})
```

Supported behavior:

| Claim field | Behavior |
| --- | --- |
| `account` | Buyer-bound reservation when non-zero. |
| `mintable` | Blocks the label when false. |
| `startTime/endTime` | Time-scoped reservation. |
| `priceOp` | `NONE`, `ADD`, or `OVERRIDE`. |
| `mintPrice/renewPrice` | Custom price effect. |

Use in `ELIGIBILITY` when reservations only gate/block labels, in `PREMIUM` when `priceOp = ADD`, or in `OVERRIDE` when reservation-specific prices should replace normal pricing. A reservation claim that emits `OVERRIDE` from `ELIGIBILITY` or `PREMIUM` will revert in the controller.

### WhitelistRule

Purpose: claim-based whitelist behavior for mints and renewals.

```solidity
WhitelistRule.Params({
    mintRoot: mintRoot,
    renewRoot: renewRoot
})
```

Runtime claim:

```solidity
WhitelistRule.Claim({
    labelHash: optionalLabelHash,
    account: optionalAccount,
    startTime: start,
    endTime: end,
    mintable: true,
    token: address(usdc),
    mintPrice: 0,
    renewPrice: 0,
    discountBps: 1000,
    priceOp: NamespaceTypes.PriceOp.NONE,
    proof: proof
})
```

Whitelist claims can be:

| Shape | Behavior |
| --- | --- |
| `account != 0`, `labelHash == 0` | Account-wide allowlist. |
| `account == 0`, `labelHash != 0` | Label-wide allowlist. |
| both set | Specific account and label. |
| `discountBps > 0` | Applies a BPS discount. |
| `priceOp = ADD/OVERRIDE` | Applies custom price effect. |
| `mintable = false` | Blocks matching claim. |

Use in `ELIGIBILITY` for allowlist-only claims, `DISCOUNT` for `discountBps`, `PREMIUM` for `priceOp = ADD`, or `OVERRIDE` for `priceOp = OVERRIDE`. A whitelist claim must not mix discount and custom price in one rule output.

## Payment Modules

### NativePaymentModule

Purpose: collect native ETH directly to one recipient.

```solidity
NativePaymentModule.Params({
    recipient: treasury
})
```

Use this when the final `Price.token` is `address(0)`. The module requires `msg.value == Price.amount`.

### ERC20PaymentModule

Purpose: collect ERC20 payment directly to one recipient.

```solidity
ERC20PaymentModule.Params({
    token: ERC20(address(usdc)),
    recipient: treasury
})
```

The payment token must be non-zero and must match the final `Price.token`.

### ERC20SplitPaymentModule

Purpose: collect ERC20 payment directly from payer to split recipients.

```solidity
ERC20SplitPaymentModule.Split[] memory splits = new ERC20SplitPaymentModule.Split[](2);
splits[0] = ERC20SplitPaymentModule.Split({recipient: alice, bps: 7500});
splits[1] = ERC20SplitPaymentModule.Split({recipient: treasury, bps: 2500});
```

The payment token must be non-zero. Splits must total `10_000` bps. The final recipient intentionally receives any rounding remainder.

## Post Hooks

### SetAddrToBuyerHook

Purpose: set one resolver `addr(node)` record after mint.

Runtime data:

| Runtime data | Behavior |
| --- | --- |
| empty | Sets addr to buyer. |
| `abi.encode(address)` | Sets addr to override address. |

### BatchSetAddrToBuyerHook

Purpose: set one or more resolver `addr(node)` records in one hook call.

Runtime data is a packed sequence of 20-byte addresses. A zero address means buyer.

This is useful for benchmarking and for flows where multiple resolver writes are expected.
