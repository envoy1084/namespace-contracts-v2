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
  - [x] renewal orchestration
  - [ ] activation ownership verification beyond root registrar admin

### Phase 2: First Modules

- [x] `SaleWindowPolicy`
- [x] `LabelLengthPolicy`
- [x] `FixedPricePricing`
- [x] `LengthBasedPricing`
- [x] `ERC20PaymentModule`
- [x] `SplitProcessor`
- [x] `NoopProcessor`
- [x] `SetAddrToBuyerHook`
- [x] `ReservationPolicy`
- [x] `MerkleWhitelistPolicy`
- [x] `ERC20BalanceGatePolicy`
- [x] `ERC721BalanceGatePolicy`
- [x] `USDOraclePricing`

### Phase 3: Tests

- [x] Test fixtures for ENSv2 registry mock/fixture setup.
- [x] Unit tests for controller activation.
- [x] Unit tests for mint orchestration.
- [x] Unit tests for each initial module.
- [x] Fuzz tests for labels, durations, pricing tables, and splits.
- [x] Integration tests for policy + pricing + payment + register flow.
- [ ] End-to-end tests using ENSv2 `PermissionedRegistry` where practical.

### Phase 4: Hardening

- [ ] Gas snapshots and optimization pass.
- [ ] Add module registry / approved modules if needed.
- [x] Add renewal flow.
- [x] Add reservation policy module.
- [x] Add ERC721/ERC20 gate policies.
- [x] Add Merkle whitelist policy.
- [x] Add USD oracle pricing.

## Progress Log

- 2026-06-16: Started Phase 1. Created core architecture scaffolding from docs:
  remappings, shared types, module interfaces, module base, and initial
  activation/mint controller.
- 2026-06-16: Added first activation modules: sale window policy, label length
  policy, fixed price pricing, ERC20 payment collection, no-op processor, and
  ERC20 split processor.
- 2026-06-16: Added initial Foundry fixtures and tests covering activation,
  mint orchestration, sale window policy, and label length policy.
- 2026-06-16: Added `LengthBasedPricing` and module tests for fixed pricing,
  length pricing, ERC20 payment collection, and ERC20 split processing.
- 2026-06-16: Added `SetAddrToBuyerHook` and resolver hook tests.
- 2026-06-16: Added controller renewal orchestration with policy, pricing,
  payment, processor, registry renewal, post-hook execution, and unit tests.
- 2026-06-16: Added `ReservationPolicy` for activation-scoped reserved labels,
  with standalone policy tests and controller integration coverage.
- 2026-06-16: Added `MerkleWhitelistPolicy` with account and account-label
  leaf modes, separate mint/renew roots, disabled-root bypasses, and unit tests.
- 2026-06-16: Added ERC20 and ERC721 balance gate policies for mint and
  renewal checks, plus mock-backed unit tests.
- 2026-06-16: Added `USDOraclePricing` for fixed USD-denominated mint and
  renewal prices converted through Chainlink-style token/USD oracles.
- 2026-06-16: Replaced scaffold Counter fuzz coverage with Namespace fuzz
  tests for label/duration minting, length pricing buckets, and ERC20 splits.
- 2026-06-16: Added an integration test for stacked policies, multiple pricing
  modules, ERC20 payment, split processing, ENSv2 registry minting, and hooks.
- 2026-06-16: Removed Foundry starter Counter contract/tests and updated the
  deploy script to deploy `NamespaceController`.
