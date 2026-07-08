# Contract Reference

This is a concise index of production contracts in `src/`.

## Controller API

| Function | Access | Summary |
| --- | --- | --- |
| `initialize(address initialOwner)` | initializer | Initializes controller owner and enables module approval enforcement. |
| `setRootRegistry(IRegistry rootRegistry)` | controller owner | Sets canonical root for future activation parent validation. |
| `activate(ActivationConfig config)` | registry admin | Creates activation and configures modules. |
| `setActivationStatus(bytes32 activationId, bool active)` | activation owner | Enables or disables activation. |
| `transferActivationOwnership(bytes32 activationId, address newOwner)` | activation owner | Transfers activation ownership to another registry admin. |
| `updateModuleConfig(bytes32 activationId, bytes32 kind, uint256 index, bytes configData)` | activation owner | Reconfigures existing module at index. |
| `setModuleApprovalRequired(bool required)` | controller owner | Toggles module approval requirement. |
| `setModuleApproval(address module, bool approved)` | controller owner | Sets approval for all module kinds. |
| `setModuleApproval(bytes32 kind, address module, bool approved)` | controller owner | Sets approval for one module kind. |
| `mint(bytes32 activationId, string label, uint64 duration, RuntimeData runtimeData)` | public payable | Executes mint flow. |
| `renew(bytes32 activationId, string label, uint64 duration, RuntimeData runtimeData)` | public payable | Executes renewal flow. |
| `getActivation(bytes32 activationId)` | view | Returns public activation metadata. |
| `getRules(bytes32 activationId)` | view | Returns rule addresses. |
| `getPostHooks(bytes32 activationId)` | view | Returns post-hook addresses. |

## Events

| Event | Emitted when |
| --- | --- |
| `ActivationCreated` | Activation is created. |
| `ActivationStatusChanged` | Activation active flag changes or activation is created active. |
| `ActivationOwnershipTransferred` | Activation owner changes. |
| `ModuleConfigUpdated` | Existing module config is updated. |
| `ModuleApprovalRequiredSet` | Approval enforcement changes. |
| `ModuleApprovalSet` | Module approval changes. |
| `RootRegistrySet` | Root registry changes. |
| `SubnameMinted` | Mint succeeds. |
| `SubnameRenewed` | Renewal succeeds. |

## Shared Types

| Type | Description |
| --- | --- |
| `ActivationConfig` | Full activation input. |
| `RuleConfig` | Rule module, phase, config data. |
| `ModuleConfig` | Payment/hook module and config data. |
| `Activation` | Public activation metadata. |
| `RuntimeData` | Per-call rule, payment, hook data. |
| `MintContext` | Context passed to modules during mint. |
| `RenewContext` | Context passed to modules during renewal. |
| `Price` | Final token and amount. |
| `RuleOutput` | Decision, price operation, flags, and price fields. |

## Enums

| Enum | Values |
| --- | --- |
| `RulePhase` | `GUARD`, `ELIGIBILITY`, `BASE_PRICE`, `PREMIUM`, `DISCOUNT`, `OVERRIDE`, `FINAL_CHECK` |
| `Decision` | `PASS`, `BLOCK`, `SKIP` |
| `PriceOp` | `NONE`, `SET_BASE`, `ADD`, `SUBTRACT`, `DISCOUNT_BPS`, `MARKUP_BPS`, `MIN`, `MAX`, `OVERRIDE` |
| `Operation` | `MINT`, `RENEW` |

## Interfaces

| Interface | Required methods |
| --- | --- |
| `INamespaceController` | Controller API, events, errors. |
| `IConfigurableModule` | `configure`. |
| `IRuleModule` | `evaluateMint`, `evaluateRenew`. |
| `IPaymentModule` | `collectMint`, `collectRenew`. |
| `IPostHookModule` | `afterMint`, `afterRenew`. |
| `IAddrResolver` | `setAddr`. |
| `IAggregatorV3` | Chainlink-compatible oracle methods. |

## Rules

| Contract | Config struct | Runtime data |
| --- | --- | --- |
| `PauseRule` | none | ignored |
| `SaleWindowRule` | `Params(uint64 startTime, uint64 endTime)` | ignored |
| `LabelLengthRule` | `Params(uint16 minLength, uint16 maxLength)` | ignored |
| `TokenBalanceRule` | `Params(ERC20 token, uint256 minBalance, uint16 discountBps, uint64 minHoldTime)` | ignored |
| `FixedPriceRule` | `Params(address token, uint128 defaultMintAmount, uint128 defaultRenewAmount, LengthPrice[] lengthPrices)` | ignored |
| `LengthPremiumRule` | `Params(address token, uint128[] mintRates, uint128[] renewRates)` | ignored |
| `LabelClassRule` | `Params(address token, LabelClass labelClass, bool requireMatch, uint128 mintAmount, uint128 renewAmount, PriceOp priceOp)` | ignored |
| `USDOracleRule` | `Params(address token, IAggregatorV3 oracle, uint8 tokenDecimals, uint64 maxStaleness, uint128 mintUsdPrice, uint128 renewUsdPrice, PriceOp priceOp)` | ignored |
| `ReservationRule` | `Params(bytes32 root)` | `abi.encode(Claim)` when root non-zero |
| `WhitelistRule` | `Params(bytes32 mintRoot, bytes32 renewRoot)` | `abi.encode(Claim)` when operation root non-zero |

## Payment Modules

| Contract | Config struct | Runtime data |
| --- | --- | --- |
| `NativePaymentModule` | `Params(address recipient)` | ignored |
| `ERC20PaymentModule` | `Params(ERC20 token, address recipient)` | ignored |
| `ERC20SplitPaymentModule` | `Params(address token, Split[] splits)` | ignored |

## Post Hooks

| Contract | Config | Runtime data |
| --- | --- | --- |
| `SetAddrToBuyerHook` | none | empty or `abi.encode(address)` |
| `BatchSetAddrToBuyerHook` | none | empty or packed 20-byte addresses |

## Main Error Categories

| Category | Representative errors |
| --- | --- |
| Activation lookup/status | `ActivationNotFound`, `ActivationNotActive` |
| Ownership/permissions | `NotActivationOwner`, `UnauthorizedActivationOwner`, `ControllerMissingRegistryRoles` |
| Registry parent validation | `RootRegistryNotConfigured`, `RegistryParentNotConfigured`, `RegistryParentChildMismatch`, `RegistryParentNodeMismatch` |
| Duration/runtime shape | `ZeroDuration`, `InvalidDurationBounds`, `DurationOutOfBounds`, `RuntimeDataLengthMismatch` |
| Module config | `ZeroModule`, `UnapprovedModule`, `ModuleIndexOutOfBounds`, `ModuleListTooLong` |
| Rule engine | `RulePhaseOrderInvalid`, `RuleBlocked`, `RequiredRuleFlagsMissing`, `RuleOperationNotAllowed`, `RulePaymentTokenMismatch` |
| Renewal | `LabelNotRenewable`, `LabelActivationMismatch` |

Module-specific errors are documented in the module spec files.
