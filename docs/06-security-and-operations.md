# Security And Operations

## Registry Permissions

Namespace depends on ENSv2 permissions. The controller can only mint or renew when the configured registry grants it the required root roles.

Required controller roles:

| Role | Use |
| --- | --- |
| `ROLE_REGISTRAR` | Mint labels through `register`. |
| `ROLE_RENEW` | Renew labels through `renew`. |

Activation owners must also retain registry admin authority. The controller checks that the activator has root registrar admin authority at activation time and before sensitive activation ownership/status updates.

## Bypass Risk

If Alice keeps a direct unrestricted path to mint subnames in the same registry, she can bypass Namespace sale rules. Production deployments should make the Namespace controller the constrained minting path for public sale inventory.

The usual setup is:

1. Alice controls `alice.eth`.
2. Alice grants the controller the registry roles needed to register and renew.
3. Alice activates `alice.eth` with rules/payment/hooks.
4. Buyers mint through `NamespaceController`.
5. The official ENSv2 registry stores the resulting subname ownership.

## Module Approval

Keep `moduleApprovalRequired = true` for curated deployments.

Approve modules by kind:

```solidity
controller.setModuleApproval(controller.MODULE_KIND_RULE(), address(rule), true);
controller.setModuleApproval(controller.MODULE_KIND_PAYMENT(), address(payment), true);
controller.setModuleApproval(controller.MODULE_KIND_POST_HOOK(), address(hook), true);
```

Approvals are kind-scoped. A payment module approved as payment is not automatically approved as a rule or hook.

## Rule Ordering

Rules must be sorted by phase. Recommended order:

```text
GUARD
ELIGIBILITY
BASE_PRICE
PREMIUM
DISCOUNT
OVERRIDE
FINAL_CHECK
```

This avoids ambiguous price behavior. For example, a token-holder discount should normally run after the base price and premiums. A reservation custom price should normally run in `OVERRIDE` so it can replace earlier pricing.

The controller accepts `PriceOp.NONE` from any phase, but non-`NONE` price operations are phase-limited:

| Phase | Allowed non-`NONE` price ops |
| --- | --- |
| `GUARD` | none |
| `ELIGIBILITY` | none |
| `BASE_PRICE` | `SET_BASE` |
| `PREMIUM` | `ADD`, `MARKUP_BPS`, `MIN` |
| `DISCOUNT` | `SUBTRACT`, `DISCOUNT_BPS`, `MAX` |
| `OVERRIDE` | `OVERRIDE` |
| `FINAL_CHECK` | `MIN`, `MAX` |

The controller also rejects repeated base prices, discounts before any price exists, mixed payment tokens, and any price change after `OVERRIDE`.

## Claims

`ReservationRule` and `WhitelistRule` use double-hashed Merkle leaves and runtime claims.

Operational requirements:

- publish the claim schema used by the sale backend;
- generate roots from normalized labels;
- store roots in activation config;
- send the matching runtime claim at the correct `ruleData[]` index;
- rotate roots with `updateModuleConfig` when reservations or allowlists change.

Reservation claims can:

- reserve a label for a specific account;
- block a label entirely;
- expire or start later;
- add a custom amount;
- override normal pricing.

Whitelist claims can:

- allow a specific account;
- allow a specific label;
- allow an account-label pair;
- block matching claims;
- apply a discount;
- add or override price.

## Oracle Pricing

`USDOracleRule` depends on a Chainlink-compatible token/USD oracle.

Use conservative settings:

| Setting | Recommendation |
| --- | --- |
| `maxStaleness` | Set a non-zero bound appropriate for the asset. |
| `tokenDecimals` | Match the payment token exactly. |
| `priceOp` | Use `SET_BASE` for a USD base price or `ADD` for a USD premium. |

The rule rejects:

- non-positive oracle answers;
- incomplete rounds;
- stale answers.

## Payment

The controller only calls payment modules when final price or `msg.value` is non-zero.

Current payment modules:

| Module | Use |
| --- | --- |
| `NativePaymentModule` | One native ETH recipient. |
| `ERC20PaymentModule` | One recipient. |
| `ERC20SplitPaymentModule` | Direct split to multiple recipients. |

Native ETH pricing is represented by `Price.token == address(0)` and must use `NativePaymentModule`. ERC20 payment modules reject `address(0)` tokens during configuration and reject non-zero native value during collection.

## Reentrancy And External Calls

`NamespaceController.mint` and `renew` are `nonReentrant`.

External calls happen in this order:

```text
rules -> registry -> payment -> hooks
```

Payment happens after the registry write, but the transaction is atomic. If payment or a hook reverts, the registry write reverts with the rest of the transaction.

If any later call reverts, the whole transaction reverts.

## Gas Controls

Gas-sensitive knobs:

| Area | Guidance |
| --- | --- |
| Rule count | Keep common activations to a small ordered stack. |
| Claim proofs | Proof depth grows with Merkle set size. |
| Hooks | Resolver writes are expensive. Batch only when needed. |
| Payment | Use `ERC20SplitPaymentModule` instead of extra settlement layers. |
| Config storage | Single module lists are stored directly; longer lists use SSTORE2. |

## Deployment Checklist

1. Deploy controller implementation and proxy.
2. Deploy rule, payment, and hook module implementations/proxies.
3. Initialize every module with `(controller, owner)`.
4. Approve curated modules on the controller.
5. Grant controller registry roles for target namespace.
6. Activate namespace with sorted rules.
7. Run a dry-run mint on a test label.
8. Publish activation ID, supported labels, pricing, and claim generation rules.
