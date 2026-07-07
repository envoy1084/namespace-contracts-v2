# Mint And Renewal Flow

Mint and renewal calls use stored activation config plus per-call runtime data.

## Runtime Data

`NamespaceTypes.RuntimeData` contains:

| Field | Meaning |
| --- | --- |
| `ruleData[]` | One entry per configured rule, same order as activation rules. |
| `paymentData` | Runtime data for the payment module. |
| `postHookData[]` | One entry per configured post hook. |

Runtime data is not configuration. Configuration is stored at activation time. Runtime data proves facts that differ per buyer or label, such as Merkle claims.

Example reservation claim:

```solidity
ReservationRule.Claim memory claim = ReservationRule.Claim({
    labelHash: keccak256(bytes("vip")),
    account: buyer,
    startTime: 0,
    endTime: uint64(block.timestamp + 30 days),
    mintable: true,
    token: address(usdc),
    mintPrice: 1000e6,
    renewPrice: 100e6,
    priceOp: NamespaceTypes.PriceOp.OVERRIDE,
    proof: proof
});

runtimeData.ruleData[reservationRuleIndex] = abi.encode(claim);
```

## Mint Sequence

```mermaid
sequenceDiagram
    participant Buyer
    participant Controller
    participant Rule
    participant Payment
    participant Registry
    participant Hook

    Buyer->>Controller: mint(activationId, label, duration, runtimeData)
    Controller->>Controller: load activation
    Controller->>Controller: validate runtime lengths
    Controller->>Controller: build MintContext
    loop each configured rule
        Controller->>Rule: evaluateMint(ctx, ruleData[i])
        Rule-->>Controller: RuleOutput
        Controller->>Controller: validate phase/op and apply decision, flags, price effect
    end
    Controller->>Registry: register(label, buyer, resolver, roles, expiry)
    Registry-->>Controller: tokenId
    opt final price or msg.value is non-zero
        Controller->>Payment: collectMint(ctx, price, paymentData)
    end
    loop each post hook
        Controller->>Hook: afterMint(ctx, tokenId, postHookData[i])
    end
    Controller-->>Buyer: tokenId
```

## Renewal Sequence

```mermaid
sequenceDiagram
    participant Payer
    participant Controller
    participant Registry
    participant Rule
    participant Payment
    participant Hook

    Payer->>Controller: renew(activationId, label, duration, runtimeData)
    Controller->>Registry: getState(labelId)
    Registry-->>Controller: tokenId and current expiry
    Controller->>Controller: build RenewContext
    loop each configured rule
        Controller->>Rule: evaluateRenew(ctx, ruleData[i])
        Rule-->>Controller: RuleOutput
        Controller->>Controller: validate phase/op and apply decision, flags, price effect
    end
    Controller->>Registry: renew(tokenId, newExpiry)
    opt final price or msg.value is non-zero
        Controller->>Payment: collectRenew(ctx, price, paymentData)
    end
    loop each post hook
        Controller->>Hook: afterRenew(ctx, postHookData[i])
    end
    Controller-->>Payer: newExpiry
```

The current implementation writes the ENSv2 registry before collecting payment. This is atomic: if payment or a hook reverts, the whole transaction reverts, including the registry write.

## Price Composition

The controller starts with:

```solidity
Price({token: address(0), amount: 0})
```

Each rule can return a `PriceOp`.

| PriceOp | Effect |
| --- | --- |
| `NONE` | No price change. |
| `SET_BASE` | Sets amount to `output.amount`. |
| `ADD` | Adds `output.amount`. |
| `SUBTRACT` | Subtracts with a floor at zero. |
| `DISCOUNT_BPS` | Applies basis point discount to current amount, rounding the remaining non-zero amount up. |
| `MARKUP_BPS` | Applies basis point markup to current amount, rounding up. |
| `MIN` | Raises amount to a minimum. |
| `MAX` | Caps amount at a maximum. |
| `OVERRIDE` | Replaces amount with `output.amount`. |

Absolute price operations also set/check the payment token. The default engine does not allow mixed payment tokens in one evaluation.

The controller also enforces phase/output compatibility. `PriceOp.NONE` is accepted from every phase.

| Phase | Legal non-`NONE` price ops |
| --- | --- |
| `GUARD` | none |
| `ELIGIBILITY` | none |
| `BASE_PRICE` | `SET_BASE` |
| `PREMIUM` | `ADD`, `MARKUP_BPS`, `MIN` |
| `DISCOUNT` | `SUBTRACT`, `DISCOUNT_BPS`, `MAX` |
| `OVERRIDE` | `OVERRIDE` |
| `FINAL_CHECK` | `MIN`, `MAX` |

This means an allowlist used only for eligibility should be configured in `ELIGIBILITY` and return no price operation. If the same allowlist concept gives a discount, configure that rule instance in `DISCOUNT`. If it sets an exact price, configure it in `OVERRIDE`.

Strict price-state checks:

| Invalid state | Result |
| --- | --- |
| second `SET_BASE` | reverts with `RuleBasePriceAlreadySet` |
| price operation after `OVERRIDE` | reverts with `RulePriceAlreadyOverridden` |
| `SUBTRACT`, `DISCOUNT_BPS`, `MARKUP_BPS`, or `MAX` before any price exists | reverts with `RulePriceOperationBeforePrice` |
| price operation not allowed by phase | reverts with `RuleOperationNotAllowed` |

## Example: Reserved Custom Price

For `reserved.alice.eth`:

```text
FixedPriceRule      SET_BASE 10 USDC
LengthPremiumRule   ADD      2 USDC
ReservationRule     OVERRIDE 1000 USDC
Final price                  1000 USDC
```

For the wrong buyer:

```text
ReservationRule reverts ReservedForDifferentAccount
```

For a blocked reservation:

```text
ReservationRule reverts ReservedLabelBlocked
```

## Failure Behavior

Any revert reverts the full transaction, including registry writes and ERC20 transfers made earlier in the same transaction.

Common failures:

| Failure | Source |
| --- | --- |
| Runtime length mismatch | Controller |
| Label outside bounds | `LabelLengthRule` |
| Sale closed | `SaleWindowRule` |
| Missing claim | `ReservationRule` or `WhitelistRule` |
| Rule output not allowed in its phase | Controller |
| Conflicting price operation | Controller |
| Mixed payment tokens | Controller |
| Wrong payment token | Payment module |
| Label unavailable | ENSv2 registry |
