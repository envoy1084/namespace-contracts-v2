# Architecture Decisions

This document explains why the current Namespace design uses activations, a unified rule interface, strict rule phases, one payment module, and the official ENSv2 registry.

## Decision 1: Use Official ENSv2 Registry, Not A Custom Registry

Namespace mints through `IPermissionedRegistry.register` and renews through `IPermissionedRegistry.renew`.

Why:

| Reason | Explanation |
| --- | --- |
| ENSv2 stays canonical | Ownership, expiry, resolver, roles, and token id remain in the official registry. |
| Less duplicated state | Namespace does not need to mirror label ownership or expiry. |
| Better composability | External ENSv2-aware tooling reads the official registry. |
| Smaller trust boundary | Namespace is sale logic, not an alternate naming system. |

Tradeoff:

| Tradeoff | Consequence |
| --- | --- |
| Registry admins can bypass Namespace if they retain direct mint authority. | Production deployments must align ENSv2 permissions with the desired trust model. |
| Namespace depends on ENSv2 role behavior. | Activation and runtime checks verify authority where possible, but the registry is still an external dependency. |

## Decision 1A: Type The Registry As IPermissionedRegistry

The controller currently targets ENSv2 `PermissionedRegistry` and `UserRegistry`, so activation stores `IPermissionedRegistry`.

`IStandardRegistry` is the lower-level registry interface and includes `register` and `renew`, but it does not include the permission and state APIs that Namespace uses for safety:

| Current controller need | Why `IStandardRegistry` is insufficient |
| --- | --- |
| Verify activation owner has registrar-admin and renew-admin roles. | Requires `hasRootRoles` from ENSv2 enhanced access control. |
| Verify controller has register and renew roles before activation succeeds. | Requires `hasRootRoles`. |
| Check renewal label status is `REGISTERED`. | Requires `IPermissionedRegistry.getState` and `Status`. |
| Emit the active registry token id on renewal. | Requires `getState` or `getTokenId` for versioned token ids. |

Use `IStandardRegistry` only in a future generic-registry adapter where these permission guarantees are deliberately removed or replaced.

See [Activation Interface Recommendations](./16-activation-interface-recommendations.md) for the detailed interface comparison.

## Decision 2: Use Activations

An activation is a stored sale configuration for one namespace.

Why:

| Reason | Explanation |
| --- | --- |
| Buyers should not submit sale config | Buyers only pass runtime proofs/input. They cannot alter pricing or module addresses at mint time. |
| Module state is activation-scoped | Each module stores parameters by `activationId`, so one module can support many sales. |
| Sale stack is auditable | Indexers and users can inspect rule order, payment module, and hooks once. |
| Renewals can be tied to the original sale | `labelActivations[registry][labelHash]` records which activation minted a label. |

Tradeoff:

| Tradeoff | Consequence |
| --- | --- |
| Module addresses/order are fixed after activation. | Changing the stack requires a new activation. Existing module parameters can be updated. |
| Multiple uses of the same module address share one config per activation. | Use separate module proxy addresses when the same implementation needs different configs in one activation. |

## Decision 2A: Prefer One Current Mint Activation Per Namespace

The current contracts allow multiple activation ids for the same registry and parent node. That is useful for iteration but not ideal for user-facing sales.

Recommended product direction:

```text
one current mint activation per canonical registry
historical activations can remain renewal-enabled
```

Do not enforce "one activation forever." Module stacks are immutable, so replacing a sale stack requires a new activation. The safer model is to make only one activation current for new mints while preserving old activation ids for renewals unless an explicit migration is performed.

Recommended future status model:

| Field | Purpose |
| --- | --- |
| `mintEnabled` | Only true for the current mint activation for a registry. |
| `renewEnabled` | Can remain true for historical activations. |
| `archived` | Marks an activation as intentionally retired. |

See [Activation Interface Recommendations](./16-activation-interface-recommendations.md) for the recommended replacement flow.

## Decision 3: Use One Rule Interface For Eligibility And Pricing

The old mental model of "check modules" plus "pricing modules" is too rigid. A real policy often affects both access and price.

Examples:

| Module idea | Eligibility | Pricing |
| --- | --- | --- |
| Reservation | Must prove label-specific claim; may block. | Can override price for that label. |
| Whitelist | Must prove account or label claim. | Can discount or exact-price. |
| Token holder | Must hold token and optionally satisfy hold time. | Can receive discount. |
| World ID or human verification | Must prove unique human status. | Can receive lower price or free claim. |

The single interface is:

```solidity
function evaluateMint(MintContext calldata ctx, bytes calldata runtimeData)
    external
    returns (RuleOutput memory);

function evaluateRenew(RenewContext calldata ctx, bytes calldata runtimeData)
    external
    returns (RuleOutput memory);
```

Why:

| Reason | Explanation |
| --- | --- |
| Fewer module types | Future integrations do not need a new controller interface just because they both gate and price. |
| Runtime data stays aligned | One `ruleData[i]` goes to one configured rule. |
| Shared composition engine | The controller can validate all rule effects in one deterministic state machine. |

## Decision 4: Strict Rule Phases

Unified rules are flexible, so the controller restricts price effects by phase.

```text
GUARD -> ELIGIBILITY -> BASE_PRICE -> PREMIUM -> DISCOUNT -> OVERRIDE -> FINAL_CHECK
```

Why:

| Problem without phases | Phase-based solution |
| --- | --- |
| A whitelist rule could unexpectedly rewrite price before base price exists. | `ELIGIBILITY` cannot emit price operations. |
| Multiple modules could define conflicting base prices. | Only `BASE_PRICE` can emit `SET_BASE`, and only one base is accepted. |
| Discounts could run before there is a price. | Discount-like operations require prior price mutation. |
| A reservation exact price could be modified later. | `OVERRIDE` locks price against later mutations. |
| Future modules could become hard to audit. | Phase and `PriceOp` describe intended effect explicitly. |

The design keeps modules reusable while making each activation's behavior deterministic.

## Decision 5: One Payment Module Per Activation

Rules compose a single final `Price { token, amount }`. A single payment module settles it.

Why:

| Reason | Explanation |
| --- | --- |
| One final asset | The rule engine rejects mixed tokens for one mint/renew. |
| Clear settlement boundary | Payment modules do not need to coordinate with each other. |
| Split logic belongs in payment module | `ERC20SplitPaymentModule` can split funds internally without multiple payment hooks. |
| Easier audits | Payment dispatch is one external call per operation when payment is needed. |

Tradeoff:

| Tradeoff | Consequence |
| --- | --- |
| Multi-token checkout is not native. | A custom payment module would need to implement any more complex settlement flow. |
| Payment module cannot be changed inside the same activation. | A new payment module address requires a new activation. Existing module config can be updated. |

## Decision 6: Payment After Registry Write

Current order:

```text
rules -> registry -> payment -> hooks
```

Why:

| Reason | Explanation |
| --- | --- |
| Hooks need registry context | Hooks receive token id and operate after successful registration. |
| Payment modules receive final context | Payment settlement gets the exact computed price and operation context. |
| Atomic rollback | If payment or hooks revert, the entire transaction reverts, including registry state. |

Risk:

| Risk | Control |
| --- | --- |
| External calls after registry write can revert. | Curate payment and hook modules; test full end-to-end flows. |
| Malicious hook/payment module is on the critical path. | Keep module approvals enabled and review approved modules. |

## Decision 7: Compact Module-List Storage

The controller stores module lists as:

| Count | Storage |
| --- | --- |
| `0` | Zero address and zero count. |
| `1` | Module address directly. |
| `2+` | Packed bytes in SSTORE2 bytecode. |

Rules store 21 bytes per entry: 20-byte module address plus 1-byte phase.

Why:

| Reason | Explanation |
| --- | --- |
| Common case is cheap | One-module lists avoid dynamic array reads. |
| Large stacks avoid dynamic storage arrays | SSTORE2 stores packed module data in bytecode. |
| Rule phases are read with module addresses | Phase metadata travels with each rule reference. |

Tradeoff:

| Tradeoff | Consequence |
| --- | --- |
| List shape cannot be edited in place. | Existing activations can update module config but not module list membership. |
| SSTORE2 read cost appears for multi-module lists. | Gas scales with stack size; benchmark realistic stacks. |

## Decision 8: Runtime Data Is Per Module

`RuntimeData` contains:

```solidity
bytes[] ruleData;
bytes paymentData;
bytes[] postHookData;
```

Why:

| Reason | Explanation |
| --- | --- |
| Buyers provide proofs, not config | Runtime data proves per-call facts. |
| Module indexing is explicit | `ruleData[i]` maps to the `i`th configured rule. |
| Controller validates array lengths | Prevents silent missing or extra module input. |

Tradeoff:

| Tradeoff | Consequence |
| --- | --- |
| Client must know module order. | Indexers/UI should read `getRules` and `getPostHooks` and construct runtime arrays exactly. |
| Payment data is not length-checked by the controller. | Payment module is responsible for interpreting or rejecting its runtime data. |

## Decision 9: Activation Owner Must Retain Registry Admin Authority

The controller checks that the activation owner still has ENSv2 registrar-admin and renew-admin authority before sensitive operations.

Why:

| Reason | Explanation |
| --- | --- |
| Prevent stale operators | An account that lost registry authority should not manage sale config. |
| Aligns sale control with ENSv2 control | The owner of Namespace sale config should still be authorized over the underlying namespace. |
| Safer ownership transfer | New activation owner must also be a registry admin. |

Tradeoff:

| Tradeoff | Consequence |
| --- | --- |
| Losing admin roles pauses practical use. | Mint/renew/config operations can fail until ownership/roles are corrected. |
| Fully trust-minimized sales need extra governance design. | If a seller should not retain authority, ENSv2 permissions and controller checks must be designed intentionally around that model. |
