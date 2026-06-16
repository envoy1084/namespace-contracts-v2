# Namespace Issuance Gas Benchmarks

These benchmarks measure activation setup, end-to-end minting, and individual module functions for Namespace subname issuance.

The minting benchmarks are end to end for the Namespace mint path: buyer calls `NamespaceController.mint`, configured policies are checked, pricing modules are evaluated, ERC20 payment is collected, the processor and post-hooks run when configured, and the mint is executed against the official ENSv2 `PermissionedRegistry` implementation from `lib/contracts-v2`.

Reference: [Foundry gas tracking](https://www.getfoundry.sh/forge/gas-tracking).

Run and regenerate this file:

```sh
./scripts/generate-benchmarks.sh
```

## Assumptions

- ETH price: `$3000`
- USD cost formula: `gasUsed * gasPriceGwei * 1e-9 * ETH_PRICE_USD`
- `Gas consumed @ 1 gwei` is the transaction fee in gwei at a 1 gwei gas price.
- Reservation and whitelist set sizes are represented by Merkle proof depth. Activation stores one root, so activation gas is intentionally flat across 10, 100, 200, or 1000-entry sets.
- Resolver record benchmarks use repeated `SetAddrToBuyerHook` addr writes because the current hook surface benchmarks resolver post-hook count, not distinct resolver record types.

## Activation Benchmarks

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_activation_00_freeNoPolicies()` | free No Policies | 245444 | 245444 | $0.073633 | $0.368166 | $0.736332 | $2.208996 | $3.681660 |
| `testBenchmark_activation_01_twoPoliciesSaleAndLength()` | two Policies Sale And Length | 361688 | 361688 | $0.108506 | $0.542532 | $1.085064 | $3.255192 | $5.425320 |
| `testBenchmark_activation_02_threePoliciesWithERC20Gate()` | three Policies With ERC20 Gate | 442845 | 442845 | $0.132854 | $0.664268 | $1.328535 | $3.985605 | $6.642675 |
| `testBenchmark_activation_03_fourPoliciesReservation10()` | four Policies Reservation10 | 506352 | 506352 | $0.151906 | $0.759528 | $1.519056 | $4.557168 | $7.595280 |
| `testBenchmark_activation_04_fourPoliciesReservation100()` | four Policies Reservation100 | 508409 | 508409 | $0.152523 | $0.762614 | $1.525227 | $4.575681 | $7.626135 |
| `testBenchmark_activation_05_fourPoliciesReservation200()` | four Policies Reservation200 | 509052 | 509052 | $0.152716 | $0.763578 | $1.527156 | $4.581468 | $7.635780 |
| `testBenchmark_activation_06_fivePoliciesWhitelist10()` | five Policies Whitelist10 | 588464 | 588464 | $0.176539 | $0.882696 | $1.765392 | $5.296176 | $8.826960 |
| `testBenchmark_activation_07_fivePoliciesWhitelist100()` | five Policies Whitelist100 | 590509 | 590509 | $0.177153 | $0.885764 | $1.771527 | $5.314581 | $8.857635 |
| `testBenchmark_activation_08_fivePoliciesWhitelist1000()` | five Policies Whitelist1000 | 592542 | 592542 | $0.177763 | $0.888813 | $1.777626 | $5.332878 | $8.888130 |
| `testBenchmark_activation_09_fixedPriceFiveLengthRules()` | fixed Price Five Length Rules | 630409 | 630409 | $0.189123 | $0.945614 | $1.891227 | $5.673681 | $9.456135 |
| `testBenchmark_activation_10_lengthBasedFiveRules()` | length Based Five Rules | 533510 | 533510 | $0.160053 | $0.800265 | $1.600530 | $4.801590 | $8.002650 |
| `testBenchmark_activation_11_emojiOnlyPricing()` | emoji Only Pricing | 369130 | 369130 | $0.110739 | $0.553695 | $1.107390 | $3.322170 | $5.536950 |
| `testBenchmark_activation_12_numberOnlyPricing()` | number Only Pricing | 369176 | 369176 | $0.110753 | $0.553764 | $1.107528 | $3.322584 | $5.537640 |
| `testBenchmark_activation_13_allPoliciesPricingSplitFiveHooks()` | all Policies Pricing Split Five Hooks | 1546502 | 1546502 | $0.463951 | $2.319753 | $4.639506 | $13.918518 | $23.197530 |

## Minting Benchmarks

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_mint_00_freeNoPolicies()` | free No Policies | 197931 | 197931 | $0.059379 | $0.296897 | $0.593793 | $1.781379 | $2.968965 |
| `testBenchmark_mint_01_twoPoliciesSaleAndLength()` | two Policies Sale And Length | 222692 | 222692 | $0.066808 | $0.334038 | $0.668076 | $2.004228 | $3.340380 |
| `testBenchmark_mint_02_threePoliciesWithERC20Gate()` | three Policies With ERC20 Gate | 242508 | 242508 | $0.072752 | $0.363762 | $0.727524 | $2.182572 | $3.637620 |
| `testBenchmark_mint_03_reservation10Proof()` | reservation10 Proof | 276671 | 276671 | $0.083001 | $0.415007 | $0.830013 | $2.490039 | $4.150065 |
| `testBenchmark_mint_04_reservation100Proof()` | reservation100 Proof | 283839 | 283839 | $0.085152 | $0.425759 | $0.851517 | $2.554551 | $4.257585 |
| `testBenchmark_mint_05_reservation200Proof()` | reservation200 Proof | 286226 | 286226 | $0.085868 | $0.429339 | $0.858678 | $2.576034 | $4.293390 |
| `testBenchmark_mint_06_whitelist10Proof()` | whitelist10 Proof | 298449 | 298449 | $0.089535 | $0.447674 | $0.895347 | $2.686041 | $4.476735 |
| `testBenchmark_mint_07_whitelist100Proof()` | whitelist100 Proof | 305658 | 305658 | $0.091697 | $0.458487 | $0.916974 | $2.750922 | $4.584870 |
| `testBenchmark_mint_08_whitelist1000Proof()` | whitelist1000 Proof | 312804 | 312804 | $0.093841 | $0.469206 | $0.938412 | $2.815236 | $4.692060 |
| `testBenchmark_mint_09_fixedPriceERC20()` | fixed Price ERC20 | 250804 | 250804 | $0.075241 | $0.376206 | $0.752412 | $2.257236 | $3.762060 |
| `testBenchmark_mint_10_fixedPriceFiveLengthRules()` | fixed Price Five Length Rules | 262680 | 262680 | $0.078804 | $0.394020 | $0.788040 | $2.364120 | $3.940200 |
| `testBenchmark_mint_11_lengthBasedFiveRules()` | length Based Five Rules | 275646 | 275646 | $0.082694 | $0.413469 | $0.826938 | $2.480814 | $4.134690 |
| `testBenchmark_mint_12_emojiOnlyPricing()` | emoji Only Pricing | 249526 | 249526 | $0.074858 | $0.374289 | $0.748578 | $2.245734 | $3.742890 |
| `testBenchmark_mint_13_numberOnlyPricing()` | number Only Pricing | 249291 | 249291 | $0.074787 | $0.373937 | $0.747873 | $2.243619 | $3.739365 |
| `testBenchmark_mint_14_erc20SplitProcessor()` | erc20 Split Processor | 328954 | 328954 | $0.098686 | $0.493431 | $0.986862 | $2.960586 | $4.934310 |
| `testBenchmark_mint_15_resolverOneRecord()` | resolver One Record | 253758 | 253758 | $0.076127 | $0.380637 | $0.761274 | $2.283822 | $3.806370 |
| `testBenchmark_mint_16_resolverThreeRecords()` | resolver Three Records | 290467 | 290467 | $0.087140 | $0.435701 | $0.871401 | $2.614203 | $4.357005 |
| `testBenchmark_mint_17_resolverFiveRecords()` | resolver Five Records | 327156 | 327156 | $0.098147 | $0.490734 | $0.981468 | $2.944404 | $4.907340 |
| `testBenchmark_mint_18_fullStackAllPoliciesPricingSplitFiveHooks()` | full Stack All Policies Pricing Split Five Hooks | 602077 | 602077 | $0.180623 | $0.903116 | $1.806231 | $5.418693 | $9.031155 |

## Policy Function Profile

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_profile_policy_00_saleWindow_checkMint()` | sale Window check Mint | 30021 | 30021 | $0.009006 | $0.045032 | $0.090063 | $0.270189 | $0.450315 |
| `testBenchmark_profile_policy_01_labelLength_checkMint()` | label Length check Mint | 30217 | 30217 | $0.009065 | $0.045326 | $0.090651 | $0.271953 | $0.453255 |
| `testBenchmark_profile_policy_02_erc20Gate_checkMint()` | erc20 Gate check Mint | 37598 | 37598 | $0.011279 | $0.056397 | $0.112794 | $0.338382 | $0.563970 |
| `testBenchmark_profile_policy_03_reservation10_checkMint()` | reservation10 check Mint | 42688 | 42688 | $0.012806 | $0.064032 | $0.128064 | $0.384192 | $0.640320 |
| `testBenchmark_profile_policy_04_reservation100_checkMint()` | reservation100 check Mint | 49861 | 49861 | $0.014958 | $0.074792 | $0.149583 | $0.448749 | $0.747915 |
| `testBenchmark_profile_policy_05_reservation200_checkMint()` | reservation200 check Mint | 52294 | 52294 | $0.015688 | $0.078441 | $0.156882 | $0.470646 | $0.784410 |
| `testBenchmark_profile_policy_06_whitelist10_checkMint()` | whitelist10 check Mint | 39775 | 39775 | $0.011933 | $0.059663 | $0.119325 | $0.357975 | $0.596625 |
| `testBenchmark_profile_policy_07_whitelist100_checkMint()` | whitelist100 check Mint | 47035 | 47035 | $0.014110 | $0.070553 | $0.141105 | $0.423315 | $0.705525 |
| `testBenchmark_profile_policy_08_whitelist1000_checkMint()` | whitelist1000 check Mint | 54270 | 54270 | $0.016281 | $0.081405 | $0.162810 | $0.488430 | $0.814050 |
| `testBenchmark_profile_policy_09_pausePolicy_checkMint()` | pause Policy check Mint | 29768 | 29768 | $0.008930 | $0.044652 | $0.089304 | $0.267912 | $0.446520 |

## Pricing Function Profile

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_profile_pricing_00_fixedDefault_quoteMint()` | fixed Default quote Mint | 28389 | 28389 | $0.008517 | $0.042584 | $0.085167 | $0.255501 | $0.425835 |
| `testBenchmark_profile_pricing_01_fixedFiveLengthRules_quoteMint()` | fixed Five Length Rules quote Mint | 40310 | 40310 | $0.012093 | $0.060465 | $0.120930 | $0.362790 | $0.604650 |
| `testBenchmark_profile_pricing_02_lengthBasedFiveRules_quoteMint()` | length Based Five Rules quote Mint | 28703 | 28703 | $0.008611 | $0.043055 | $0.086109 | $0.258327 | $0.430545 |
| `testBenchmark_profile_pricing_03_emojiOnly_quoteMint()` | emoji Only quote Mint | 27324 | 27324 | $0.008197 | $0.040986 | $0.081972 | $0.245916 | $0.409860 |
| `testBenchmark_profile_pricing_04_numberOnly_quoteMint()` | number Only quote Mint | 27022 | 27022 | $0.008107 | $0.040533 | $0.081066 | $0.243198 | $0.405330 |
| `testBenchmark_profile_pricing_05_letterOnly_quoteMint()` | letter Only quote Mint | 31021 | 31021 | $0.009306 | $0.046532 | $0.093063 | $0.279189 | $0.465315 |

## Payment, Processor, And Hook Function Profile

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_profile_hook_00_setAddrToBuyer_afterMint()` | set Addr To Buyer after Mint | 78626 | 78626 | $0.023588 | $0.117939 | $0.235878 | $0.707634 | $1.179390 |
| `testBenchmark_profile_payment_00_collectMintERC20()` | collect Mint ERC20 | 59343 | 59343 | $0.017803 | $0.089015 | $0.178029 | $0.534087 | $0.890145 |
| `testBenchmark_profile_processor_00_noop_processMint()` | noop process Mint | 36998 | 36998 | $0.011099 | $0.055497 | $0.110994 | $0.332982 | $0.554970 |
| `testBenchmark_profile_processor_01_split_processMint()` | split process Mint | 102209 | 102209 | $0.030663 | $0.153314 | $0.306627 | $0.919881 | $1.533135 |

## Scenario Notes

| Area | Notes |
| --- | --- |
| Activations | Activation benchmarks call `NamespaceController.activate` with the named policy, pricing, processor, and hook configuration. |
| Minting | Minting benchmarks execute one `NamespaceController.mint` transaction after activation setup in `setUp()`. |
| Reservations | Reservation proof scenarios use proofs for the named set size. Larger sets increase proof depth and mint gas, while activation gas remains root-only. |
| Whitelists | Whitelist scenarios use `ACCOUNT_LABEL` leaves so both buyer and requested label are proven. |
| Resolver hooks | 1, 3, and 5 record scenarios benchmark 1, 3, and 5 post-mint resolver addr hook calls. |
| Full stack | The full-stack benchmark combines sale window, label length, ERC20 gate, reservation, whitelist, class pricing, fixed pricing, length pricing, ERC20 payment, split processing, and five resolver hooks. |
| Function profiles | Profile rows call individual module functions directly with realistic activation config so hotspots can be compared before optimizing internals. |
