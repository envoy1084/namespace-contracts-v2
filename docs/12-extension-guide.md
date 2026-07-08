# Extension Guide

Namespace is designed so most future features can be added as modules without changing the controller.

Use a controller change only when the feature needs a new execution phase, a different price representation, different payer/buyer semantics, or different registry operation.

## Adding A Rule Module

Implement:

```solidity
contract MyRule is NamespaceRule {
    function configure(bytes32 activationId, bytes calldata configData)
        external
        onlyController
    {
        // decode, validate, store by activationId
    }

    function evaluateMint(MintContext calldata ctx, bytes calldata runtimeData)
        external
        returns (RuleOutput memory output)
    {
        // check and return output
    }

    function evaluateRenew(RenewContext calldata ctx, bytes calldata runtimeData)
        external
        returns (RuleOutput memory output)
    {
        // check and return output
    }
}
```

Required design decisions:

| Decision | Questions |
| --- | --- |
| Activation config | What is fixed for the sale? Root, verifier address, price table, issuer, time bounds? |
| Runtime data | What changes per buyer/label? Proof, signature, nullifier, attestation id? |
| Phase | Does the rule only gate, set base price, add premium, discount, override, or final-check? |
| Failure style | Should invalid input revert with specific error or return `Decision.BLOCK`? |
| Flags | Does this rule produce a fact that later rules should consume? |
| Renewal behavior | Same as mint, different, or disabled? |

## Choosing A Phase

| Desired behavior | Phase | Allowed price output |
| --- | --- | --- |
| Pause, deadline, fast global guard | `GUARD` | none |
| Pure allow/deny or proof verification | `ELIGIBILITY` | none |
| Establish base price | `BASE_PRICE` | `SET_BASE` |
| Add amount, markup, or floor | `PREMIUM` | `ADD`, `MARKUP_BPS`, `MIN` |
| Discount or cap | `DISCOUNT` | `SUBTRACT`, `DISCOUNT_BPS`, `MAX` |
| Replace final price | `OVERRIDE` | `OVERRIDE` |
| Enforce final bounds | `FINAL_CHECK` | `MIN`, `MAX` |

If one conceptual integration needs multiple price behaviors, prefer one of:

| Pattern | When to use |
| --- | --- |
| Separate module proxy per behavior | Same implementation, different config and phase in one activation. |
| Separate modules | Behaviors have materially different state or security assumptions. |
| One rule with constrained config | Runtime data cannot switch to an operation illegal for configured phase. |

## Using Flags

Flags let earlier rules prove facts to later rules.

Example constants:

```solidity
uint256 constant FLAG_HUMAN = 1 << 0;
uint256 constant FLAG_VERIFIED_TOKEN_HOLDER = 1 << 1;
uint256 constant FLAG_PARTNER_ALLOWLIST = 1 << 2;
```

Producer rule:

```solidity
output.decision = Decision.PASS;
output.addFlags = FLAG_HUMAN;
```

Consumer rule:

```solidity
output.decision = Decision.PASS;
output.requireFlags = FLAG_HUMAN;
output.priceOp = PriceOp.DISCOUNT_BPS;
output.bps = 2000;
```

Why flags are useful:

| Use | Benefit |
| --- | --- |
| Identity proof plus discount | Identity module does not need pricing config. |
| Multi-provider verification | One of several proof modules can add the same flag. |
| Composable final checks | Final-check module can require earlier facts. |

## Future Integration Examples

| Integration | Likely module type | Example behavior |
| --- | --- | --- |
| World ID or similar human verification | Rule | Verify proof/nullifier, add `HUMAN` flag, optionally gate or discount. |
| Gitcoin Passport or scorer | Rule | Verify score proof or attestation, discount high-score users. |
| EAS attestations | Rule | Verify attestation issuer/schema/account, gate or price by attestation. |
| Farcaster account ownership | Rule | Verify signed account proof, gate community sale. |
| NFT holder gate | Rule | Check ERC721/1155 balance, allow or discount holders. |
| ERC20 staking or ve-token status | Rule | Check balance/lock state, add discount or special price. |
| Referral code | Rule or payment module | Verify code and apply discount or revenue attribution. |
| Permit-based ERC20 payment | Payment module | Decode permit from `paymentData`, approve and collect in one call. |
| Cross-chain proof | Rule or payment module | Verify bridge/oracle proof for eligibility or payment. |
| Text record setup | Post hook | Set resolver text records after mint. |

## When Controller Changes Are Needed

Do not force everything into modules. Change the controller if the feature needs:

| Need | Why module is insufficient |
| --- | --- |
| Multiple payment tokens in one purchase | Current `Price` is one token and amount. |
| Third-party payer separate from buyer | Current contexts set payer to `msg.sender`. |
| Batch mint in one transaction | Current entry point handles one label. |
| Renewal migration between activations | Current renewal requires original activation id. |
| New registry operation | Controller currently calls only `register` and `renew`. |
| Pre-registry payment | Current order is registry then payment. |
| Optional hooks that cannot revert the mint | Current hooks are critical-path and revert transaction. |

## Module Security Checklist

Before approving a module:

| Check | Reason |
| --- | --- |
| `configure` is controller-only | Prevents arbitrary config changes. |
| Config validates all invariants | Bad config should not become active. |
| Runtime data length and decoding are strict | Prevents ambiguous calldata interpretation. |
| External calls are minimized and understood | Rules are called before registry writes but can still grief by reverting. |
| Price operation is constrained | Module should not emit operations outside intended phase. |
| Token semantics are explicit | Native versus ERC20 must be clear. |
| Renewal behavior is intentional | Do not accidentally allow cheaper renewal or bypass. |
| Reentrancy assumptions are documented | Controller is non-reentrant, but modules may call external contracts. |
| Events exist for owner-managed state changes | Off-chain monitoring needs visibility. |

## Recommended Module Documentation Template

For every new module, document:

```text
Purpose
Config ABI
Runtime ABI
Mint behavior
Renew behavior
Required phase
RuleOutput effects
Errors
Events
External calls
Security assumptions
Example activation config
Example runtime data
```
