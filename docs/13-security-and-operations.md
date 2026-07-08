# Security And Operations

This document covers production risks, deployment controls, and incident procedures.

## Main Trust Boundaries

| Boundary | Risk |
| --- | --- |
| ENSv2 registry permissions | Admins or role holders may bypass Namespace by calling registry directly. |
| Controller owner | Can upgrade controller and approve/revoke modules. |
| Module owner | Can upgrade module behavior. |
| Activation owner | Can update module config and active status while retaining registry admin authority. |
| Rule modules | Can block or price operations. |
| Payment modules | Move funds. |
| Post hooks | Execute external side effects after payment. |
| Off-chain data | Merkle roots, proofs, labels, and oracle choices must match on-chain assumptions. |

## Deployment Checklist

1. Deploy controller implementation and proxy.
2. Initialize controller with the intended owner.
3. Set `universalResolver`; the controller mirrors `universalResolver.ROOT_REGISTRY()` into `rootRegistry`.
4. Deploy module implementations/proxies.
5. Initialize every module with `(controller, moduleOwner)`.
6. Approve curated modules by kind.
7. Configure ENSv2 registry roles:
   - controller gets `ROLE_REGISTRAR | ROLE_RENEW`;
   - activation owner has `ROLE_REGISTRAR_ADMIN | ROLE_RENEW_ADMIN`.
8. Build and verify module config payloads.
9. Create activation with sorted rule phases.
10. Run test mint and test renewal on a safe label.
11. Verify payment recipient balances and resolver state.
12. Publish activation id, module list, config summary, payment token, claim schema, and root versions.

## Module Approval Policy

Keep `moduleApprovalRequired = true` for production.

Approval effects:

| Operation | Approval checked |
| --- | --- |
| Activation | Every configured rule/hook and non-zero payment module. |
| Mint/renew | Every rule, payment module if called, every hook. |
| Config update | Target module at existing index. |

Revocation effects:

| Module revoked | Effect |
| --- | --- |
| Rule | Future operations revert when that rule is reached. |
| Payment | Paid operations revert when payment is needed. |
| Hook | Future operations revert when that hook is reached. |

Use revocation as a circuit breaker. It can intentionally break live activations.

## ENSv2 Bypass Risk

If a registry admin can mint directly in ENSv2, Namespace rules can be bypassed.

Operational models:

| Model | Suitable controls |
| --- | --- |
| Trusted admin | Multisig admin, public disclosure, monitoring. |
| Strong controller enforcement | Remove direct public mint paths, timelock privileged actions, make controller the only sale route. |
| Emergency admin | Keep break-glass authority but publish rules for use. |

Namespace cannot enforce guarantees that the underlying ENSv2 permission setup contradicts.

## Claims And Roots

For Merkle-based modules:

| Requirement | Why |
| --- | --- |
| Normalize labels before hashing | On-chain hash is `keccak256(bytes(label))`. |
| Match exact claim struct order | Leaf hashes are not ABI-encoded dynamically at runtime with proof included. |
| Double-hash leaves | Modules hash fields, then hash the inner hash. |
| Sorted-pair proofs | Verifier sorts each hash pair before hashing. |
| Version roots | Users and indexers need to know which root produced a proof. |
| Rotate roots through `updateModuleConfig` | Allows claim-set changes without new activation. |

Reservation warning:

```text
root != 0 means every evaluated label needs a valid exact-label claim.
```

Whitelist warning:

```text
discountBps takes precedence over priceOp.
```

## Oracle Operations

For `USDOracleRule`:

| Check | Why |
| --- | --- |
| Oracle is token/USD | Formula assumes token price in USD. |
| `tokenDecimals` is exact | Wrong decimals misprice every operation. |
| `maxStaleness` is conservative | Stale price can overcharge or undercharge. |
| Oracle monitored | Stale or invalid oracle blocks sale operations. |
| Payment module token matches rule token | Mismatch causes payment failure. |

Oracle failure blocks the entire mint/renew because it occurs during rule evaluation.

## Payment Operations

| Concern | Control |
| --- | --- |
| ERC20 allowance | Buyer approves payment module. |
| Fee-on-transfer token | Shipped ERC20 modules reject via exact balance delta. |
| Split rounding | Last recipient receives remainder. |
| Wrong token | Payment module checks final `Price.token`. |
| Accidental native value | Non-zero `msg.value` forces payment dispatch. |
| Free mint | If price and `msg.value` are zero, payment is skipped. |

Payment after registry write is safe only because the transaction is atomic. If payment fails, registry write reverts.

## Hook Operations

| Concern | Control |
| --- | --- |
| Resolver missing | Do not configure resolver hooks with zero resolver. |
| Resolver permission | Ensure hook/controller path can call `setAddr`. |
| Hook revert | Hooks are critical path; any revert reverts mint/renew. |
| Batch repeated writes | Understand resolver semantics; standard resolver stores final value. |

Hooks are powerful enough to break otherwise valid mints. Keep hook modules curated.

## Incident Procedures

| Incident | Immediate action | Follow-up |
| --- | --- | --- |
| Bad activation config | Disable activation or pause via `PauseRule`. | Create corrected activation if module stack must change. |
| Bad Merkle root | Pause if unsafe. | Rotate root with `updateModuleConfig`. |
| Bad oracle | Pause affected activation. | Update oracle config or deploy new activation. |
| Payment recipient error | Pause sale. | Update payment config if same module can fix it. |
| Module vulnerability | Revoke module approval. | Deploy fixed module and migrate activations. |
| Resolver hook failure | Pause sale. | Fix resolver permissions or create activation without bad hook. |
| Registry role revoked | Restore roles or transfer activation ownership to valid admin. | Review ENSv2 admin procedures. |

## Monitoring

Monitor events:

| Event | Why |
| --- | --- |
| `ActivationCreated` | New sale configuration. |
| `ActivationStatusChanged` | Sale enabled/disabled. |
| `ActivationOwnershipTransferred` | Sale owner changed. |
| `ModuleConfigUpdated` | Rule/payment/hook params changed. |
| `ModuleApprovalSet` | Module allowlist changed. |
| `ModuleApprovalRequiredSet` | Approval enforcement changed. |
| `RootRegistrySet` | UniversalResolver root mirror changed. |
| `SubnameMinted` | Successful mint and final price. |
| `SubnameRenewed` | Successful renewal and final price. |

Also monitor module-specific events such as `PauseStatusChanged` and `TokenBalanceRecorded`.

## Gas Operations

Gas drivers:

| Driver | Why |
| --- | --- |
| Rule count | External call plus output validation per rule. |
| Merkle proof depth | Hashing cost grows with proof length. |
| Oracle rule | External oracle calls. |
| Token balance rule | ERC20 `balanceOf`; optional separate `recordBalance` transaction. |
| Payment splits | One ERC20 transfer per split recipient. |
| Hooks | External resolver writes. |
| Multi-module SSTORE2 lists | Bytecode reads for packed lists. |

Regenerate benchmarks:

```sh
./scripts/generate-benchmarks.sh
```

Benchmark reports:

| File | Purpose |
| --- | --- |
| `benchmarks/BENCHMARKS.md` | Index and benchmark command. |
| `benchmarks/PROFILE_BENCHMARKS.md` | Profile gas. |
| `benchmarks/SCENARIO_BENCHMARKS.md` | End-to-end scenario gas. |
