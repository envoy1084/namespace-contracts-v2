# Contract Reference

## Controller

### NamespaceController

Path: `src/NamespaceController.sol`

Responsibilities:

- create activations;
- validate registry roles;
- store compact rule and hook lists;
- configure modules;
- evaluate rules;
- collect payment;
- call official ENSv2 registry;
- run post hooks;
- expose activation metadata.

Important methods:

| Method | Purpose |
| --- | --- |
| `activate` | Create and configure a sale activation. |
| `mint` | Execute rule evaluation, payment, registry mint, and hooks. |
| `renew` | Execute rule evaluation, payment, registry renewal, and hooks. |
| `updateModuleConfig` | Reconfigure an existing rule, payment module, or hook. |
| `setActivationStatus` | Enable or disable an activation. |
| `transferActivationOwnership` | Move activation ownership to another registry admin. |
| `getActivation` | Read public activation metadata. |
| `getRules` | Read ordered rule module addresses. |
| `getPostHooks` | Read ordered post-hook addresses. |

Module kind constants:

| Constant | Meaning |
| --- | --- |
| `MODULE_KIND_RULE` | Rule modules. |
| `MODULE_KIND_PAYMENT` | Payment modules. |
| `MODULE_KIND_POST_HOOK` | Post-hook modules. |

## Shared Types

Path: `src/libraries/NamespaceTypes.sol`

Key structs:

| Struct | Purpose |
| --- | --- |
| `ActivationConfig` | Full activation input. |
| `RuleConfig` | Rule module, phase, and config data. |
| `ModuleConfig` | Payment/hook module and config data. |
| `Activation` | Public activation metadata. |
| `RuntimeData` | Per-call rule, payment, and hook data. |
| `MintContext` | Context passed to rules, payment, and hooks during mint. |
| `RenewContext` | Context passed during renewal. |
| `Price` | Final token and amount. |
| `RuleOutput` | Rule decision, price effect, and flags. |

Key enums:

| Enum | Purpose |
| --- | --- |
| `RulePhase` | Deterministic rule ordering. |
| `Decision` | `PASS`, `BLOCK`, or `SKIP`. |
| `PriceOp` | Price transformation. |

## Interfaces

| Interface | Purpose |
| --- | --- |
| `IRuleModule` | `evaluateMint` and `evaluateRenew`. |
| `IPaymentModule` | `collectMint` and `collectRenew`. |
| `IPostHookModule` | `afterMint` and `afterRenew`. |
| `IConfigurableModule` | Activation-scoped `configure`. |
| `INamespaceController` | External controller API. |
| `IAddrResolver` | Minimal resolver `setAddr`. |
| `IAggregatorV3` | Minimal Chainlink-compatible oracle interface. |

## Base Module

### NamespaceModule

Path: `src/modules/NamespaceModule.sol`

Base for activation-scoped modules. It stores:

| Field | Purpose |
| --- | --- |
| `controller` | Only this address can call `configure` and execution hooks. |
| owner | UUPS upgrade authority for the module proxy. |

### NamespaceRule

Path: `src/modules/rules/NamespaceRule.sol`

Base for rule modules. It inherits `NamespaceModule` and `IRuleModule`, and provides `_pass()`.

## Rules

| Contract | Purpose |
| --- | --- |
| `PauseRule` | Activation-owner pause switch. |
| `SaleWindowRule` | Time-window checks. |
| `LabelLengthRule` | Byte-length bounds. |
| `TokenBalanceRule` | ERC20 gate and optional discount. |
| `FixedPriceRule` | Fixed base price with exact-length overrides. |
| `LengthPremiumRule` | Per-second length premiums. |
| `LabelClassRule` | Number, letter, or emoji-only label behavior. |
| `USDOracleRule` | USD-denominated prices through token/USD oracle. |
| `ReservationRule` | Claim-based reservations, blocks, and custom prices. |
| `WhitelistRule` | Claim-based allowlists, blocks, discounts, and custom prices. |

## Payment

| Contract | Purpose |
| --- | --- |
| `ERC20PaymentModule` | Direct ERC20 collection to one recipient. |
| `ERC20SplitPaymentModule` | Direct ERC20 collection to multiple recipients by bps. |

## Hooks

| Contract | Purpose |
| --- | --- |
| `SetAddrToBuyerHook` | Sets one resolver addr record after mint. |
| `BatchSetAddrToBuyerHook` | Sets one or more resolver addr records after mint. |

## Test Support

| Contract | Purpose |
| --- | --- |
| `MockERC20` | Test ERC20. |
| `MockERC721` | Test ERC721. |
| `MockAggregatorV3` | Test token/USD oracle. |
| `RecordingPostHook` | Test hook that records last mint. |
