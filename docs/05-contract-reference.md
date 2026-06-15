# Contract Reference

This page summarizes every current project contract in `src/`.

## Core

### NamespaceController

Main entry point for namespace owners and buyers.

Responsibilities:

- create activations;
- enforce activation ownership and registry admin authority;
- enforce optional module approval;
- validate runtime data lengths;
- orchestrate policy, pricing, payment, processor, registry, and hook calls;
- expose activation metadata and module lists.

Key functions:

| Function | Purpose |
| --- | --- |
| `activate(config)` | Create and configure an activation. |
| `mint(activationId, label, duration, runtimeData)` | Mint a subname through the activation. |
| `renew(activationId, label, duration, runtimeData)` | Renew a subname through the activation. |
| `setActivationStatus(activationId, active)` | Pause or resume an activation. |
| `transferActivationOwnership(activationId, newOwner)` | Transfer activation control to another registry admin. |
| `setModuleApprovalRequired(required)` | Enable/disable module allowlisting. |
| `setModuleApproval(module, approved)` | Update module allowlist state. |
| `getActivation/getPolicies/getPricingModules/getPostHooks` | Read activation configuration. |

### NamespaceTypes

Shared type library.

Defines:

- `ModuleConfig`;
- `ActivationConfig`;
- `Activation`;
- `RuntimeData`;
- `MintContext`;
- `RenewContext`;
- `Price`.

This library is the contract between controller and modules.

### NamespaceModule

Base contract for modules.

Responsibilities:

- stores immutable `CONTROLLER`;
- provides `onlyController`;
- standardizes controller-only configuration and execution.

## Interfaces

| Interface | Purpose |
| --- | --- |
| `INamespaceController` | Public controller entry point and events. |
| `IConfigurableModule` | Shared `configure(activationId, configData)` interface. |
| `IPolicyModule` | `checkMint` and `checkRenew`. |
| `IPricingModule` | `quoteMint` and `quoteRenew`. |
| `IPaymentModule` | `collectMint` and `collectRenew`. |
| `IProcessorModule` | `processMint` and `processRenew`. |
| `IPostHookModule` | `afterMint` and `afterRenew`. |
| `IAddrResolver` | Minimal resolver setter used by `SetAddrToBuyerHook`. |
| `IAggregatorV3` | Minimal oracle interface used by `USDOraclePricing`. |

## Policies

| Contract | What it enforces |
| --- | --- |
| `SaleWindowPolicy` | Time window for mint/renew. |
| `LabelLengthPolicy` | Minimum and maximum label byte length. |
| `ERC20BalanceGatePolicy` | Minimum ERC20 balance. |
| `ERC721BalanceGatePolicy` | Minimum ERC721 balance. |
| `ReservationPolicy` | Exact label reservations by account and expiry. |
| `MerkleWhitelistPolicy` | Merkle allowlists for mints and renewals. |

## Pricing

| Contract | What it prices |
| --- | --- |
| `FixedPricePricing` | Fixed mint and renewal amounts. |
| `LengthBasedPricing` | Per-second rates selected by label byte length. |
| `USDOraclePricing` | USD-denominated prices converted through an oracle. |

## Payment And Processing

| Contract | Purpose |
| --- | --- |
| `ERC20PaymentModule` | Pulls ERC20 payment from payer to recipient. |
| `NoopProcessor` | Empty processor for direct-settlement flows. |
| `ERC20SplitProcessor` | Splits ERC20 funds by basis points. |

## Hooks

| Contract | Purpose |
| --- | --- |
| `SetAddrToBuyerHook` | Sets resolver `addr` record after mint. |

