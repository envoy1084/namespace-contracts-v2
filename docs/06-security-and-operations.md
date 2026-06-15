# Security And Operations

This page captures operational assumptions, known static-analysis notes, and deployment guidance for the current contracts.

## Registry Permissions

Namespace depends on official ENSv2 registry permissions.

For an activation to work:

- owner must have root registrar admin authority on the registry;
- controller must have root registrar and renew authority on the registry.

This prevents Namespace from minting in a registry unless the registry owner explicitly delegates those rights.

## Module Trust

Modules are external contracts called by the controller.

Production deployments should enable module approval:

```solidity
setModuleApprovalRequired(true)
setModuleApproval(module, true)
```

Without approval mode, a namespace owner can activate arbitrary module contracts. That is flexible for experimentation but risky for curated production sales.

## Reentrancy

`activate`, `mint`, and `renew` use `nonReentrant`.

The controller still intentionally calls external modules. This is the point of the architecture, so module allowlisting and module review are important.

## Timestamp Usage

Timestamp checks are intentional in:

- `SaleWindowPolicy`;
- `ReservationPolicy`;
- `USDOraclePricing`.

These checks model sale windows, reservation expiry, and oracle staleness. Do not use them for randomness.

## Payment Assumptions

`ERC20PaymentModule` is controller-only. The controller currently sets `ctx.payer = msg.sender`, so the ERC20 transfer pulls from the caller who initiated mint or renew.

For split payments:

1. Configure `ERC20PaymentModule.recipient` as `ERC20SplitProcessor`.
2. Configure `ERC20SplitProcessor` with recipients totaling `10_000` bps.
3. Processor distributes the ERC20 balance after collection.

Native ETH pricing is represented by `address(0)` in `NamespaceTypes.Price`, but the current payment implementation is ERC20-only and rejects `msg.value`.

## Static Analysis Notes

Expected Slither findings for this architecture:

| Finding | Reason |
| --- | --- |
| Calls inside loops | Policies, pricing modules, and hooks are intentionally stacked arrays. Keep array lengths bounded by UI/deployment policy. |
| Timestamp comparisons | Sale windows, reservation expiry, and oracle staleness are time-based features. |
| Arbitrary `transferFrom` | Payment is controller-only and payer is set by controller context. |
| Locking ether in ERC20 payment | The interface is payable for payment-module generality, but ERC20 module rejects non-zero `msg.value`. |

## Operational Checklist

Before opening a sale:

1. Deploy or select the official ENSv2 registry for the parent namespace.
2. Grant controller registrar and renew roles on that registry.
3. Decide whether module approval should be required.
4. Approve the modules that are allowed in production.
5. Configure policies, pricing, payment, processor, and hooks.
6. Run a dry-run mint on a test registry.
7. Monitor emitted `SubnameMinted` and `SubnameRenewed` events.

## Tooling

Use:

```sh
forge test
forge lint
solhint 'src/**/*.sol' 'test/**/*.sol'
./scripts/slither-build.sh && slither .
./scripts/generate-benchmarks.sh
```

`scripts/slither-build.sh` exists because Slither 0.11.x cannot parse metadata-only Foundry build-info files emitted for some dependency paths.

