# Namespace V2 Contracts TODO

## Current Status

- [x] Research ENSv2 architecture and document Namespace activation-based module architecture.
- [ ] Implement production Namespace V2 contracts.
- [ ] Add comprehensive unit, fuzz, integration, and end-to-end tests.
- [ ] Optimize gas after core behavior and tests are in place.

## Implementation Roadmap

### Phase 1: Core Scaffolding

- [x] Configure Foundry remappings for local `lib/` dependencies and ENSv2 source imports.
- [x] Add shared Namespace structs and errors.
- [ ] Add module interfaces:
  - [x] `IConfigurableModule`
  - [x] `IPolicyModule`
  - [x] `IPricingModule`
  - [x] `IPaymentModule`
  - [x] `IProcessorModule`
  - [x] `IPostHookModule`
- [x] Add `NamespaceModule` base contract with controller-only configuration guard.
- [x] Add `NamespaceController` with:
  - [x] activation creation
  - [x] module configuration calls
  - [x] stored activation metadata
  - [x] mint orchestration
  - [x] ENSv2 registry `register()` call
  - [x] events and custom errors
  - [ ] renewal orchestration
  - [ ] activation ownership verification beyond root registrar admin

### Phase 2: First Modules

- [x] `SaleWindowPolicy`
- [x] `LabelLengthPolicy`
- [x] `FixedPricePricing`
- [ ] `LengthBasedPricing`
- [x] `ERC20PaymentModule`
- [x] `SplitProcessor`
- [x] `NoopProcessor`
- [ ] `SetAddrToBuyerHook`

### Phase 3: Tests

- [x] Test fixtures for ENSv2 registry mock/fixture setup.
- [x] Unit tests for controller activation.
- [x] Unit tests for mint orchestration.
- [ ] Unit tests for each initial module.
- [ ] Fuzz tests for labels, durations, pricing tables, and splits.
- [ ] Integration tests for policy + pricing + payment + register flow.
- [ ] End-to-end tests using ENSv2 `PermissionedRegistry` where practical.

### Phase 4: Hardening

- [ ] Gas snapshots and optimization pass.
- [ ] Add module registry / approved modules if needed.
- [ ] Add renewal flow.
- [ ] Add reservation flow.
- [ ] Add ERC721/ERC20 gate policies.
- [ ] Add Merkle whitelist policy.
- [ ] Add USD oracle pricing.

## Progress Log

- 2026-06-16: Started Phase 1. Created core architecture scaffolding from docs:
  remappings, shared types, module interfaces, module base, and initial
  activation/mint controller.
- 2026-06-16: Added first activation modules: sale window policy, label length
  policy, fixed price pricing, ERC20 payment collection, no-op processor, and
  ERC20 split processor.
- 2026-06-16: Added initial Foundry fixtures and tests covering activation,
  mint orchestration, sale window policy, and label length policy.
