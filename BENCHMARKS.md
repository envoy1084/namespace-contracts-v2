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
| `testBenchmark_activation_00_freeNoPolicies()` | free No Policies | 222966 | 222966 | $0.066890 | $0.334449 | $0.668898 | $2.006694 | $3.344490 |
| `testBenchmark_activation_01_twoPoliciesSaleAndLength()` | two Policies Sale And Length | 351689 | 351689 | $0.105507 | $0.527533 | $1.055067 | $3.165201 | $5.275335 |
| `testBenchmark_activation_02_threePoliciesWithERC20Gate()` | three Policies With ERC20 Gate | 417858 | 417858 | $0.125357 | $0.626787 | $1.253574 | $3.760722 | $6.267870 |
| `testBenchmark_activation_03_fourPoliciesReservation10()` | four Policies Reservation10 | 488851 | 488851 | $0.146655 | $0.733276 | $1.466553 | $4.399659 | $7.332765 |
| `testBenchmark_activation_04_fourPoliciesReservation100()` | four Policies Reservation100 | 490908 | 490908 | $0.147272 | $0.736362 | $1.472724 | $4.418172 | $7.363620 |
| `testBenchmark_activation_05_fourPoliciesReservation200()` | four Policies Reservation200 | 491551 | 491551 | $0.147465 | $0.737326 | $1.474653 | $4.423959 | $7.373265 |
| `testBenchmark_activation_06_fivePoliciesWhitelist10()` | five Policies Whitelist10 | 578157 | 578157 | $0.173447 | $0.867236 | $1.734471 | $5.203413 | $8.672355 |
| `testBenchmark_activation_07_fivePoliciesWhitelist100()` | five Policies Whitelist100 | 580202 | 580202 | $0.174061 | $0.870303 | $1.740606 | $5.221818 | $8.703030 |
| `testBenchmark_activation_08_fivePoliciesWhitelist1000()` | five Policies Whitelist1000 | 582235 | 582235 | $0.174671 | $0.873353 | $1.746705 | $5.240115 | $8.733525 |
| `testBenchmark_activation_09_fixedPriceFiveLengthRules()` | fixed Price Five Length Rules | 643848 | 643848 | $0.193154 | $0.965772 | $1.931544 | $5.794632 | $9.657720 |
| `testBenchmark_activation_10_lengthBasedFiveRules()` | length Based Five Rules | 546653 | 546653 | $0.163996 | $0.819980 | $1.639959 | $4.919877 | $8.199795 |
| `testBenchmark_activation_11_emojiOnlyPricing()` | emoji Only Pricing | 382145 | 382145 | $0.114644 | $0.573218 | $1.146435 | $3.439305 | $5.732175 |
| `testBenchmark_activation_12_numberOnlyPricing()` | number Only Pricing | 382191 | 382191 | $0.114657 | $0.573287 | $1.146573 | $3.439719 | $5.732865 |
| `testBenchmark_activation_13_allPoliciesPricingSplitFiveHooks()` | all Policies Pricing Split Five Hooks | 1572478 | 1572478 | $0.471743 | $2.358717 | $4.717434 | $14.152302 | $23.587170 |

## Minting Benchmarks

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_mint_00_freeNoPolicies()` | free No Policies | 188860 | 188860 | $0.056658 | $0.283290 | $0.566580 | $1.699740 | $2.832900 |
| `testBenchmark_mint_01_twoPoliciesSaleAndLength()` | two Policies Sale And Length | 223720 | 223720 | $0.067116 | $0.335580 | $0.671160 | $2.013480 | $3.355800 |
| `testBenchmark_mint_02_threePoliciesWithERC20Gate()` | three Policies With ERC20 Gate | 246391 | 246391 | $0.073917 | $0.369586 | $0.739173 | $2.217519 | $3.695865 |
| `testBenchmark_mint_03_reservation10Proof()` | reservation10 Proof | 285657 | 285657 | $0.085697 | $0.428486 | $0.856971 | $2.570913 | $4.284855 |
| `testBenchmark_mint_04_reservation100Proof()` | reservation100 Proof | 292861 | 292861 | $0.087858 | $0.439292 | $0.878583 | $2.635749 | $4.392915 |
| `testBenchmark_mint_05_reservation200Proof()` | reservation200 Proof | 295260 | 295260 | $0.088578 | $0.442890 | $0.885780 | $2.657340 | $4.428900 |
| `testBenchmark_mint_06_whitelist10Proof()` | whitelist10 Proof | 312505 | 312505 | $0.093752 | $0.468758 | $0.937515 | $2.812545 | $4.687575 |
| `testBenchmark_mint_07_whitelist100Proof()` | whitelist100 Proof | 319752 | 319752 | $0.095926 | $0.479628 | $0.959256 | $2.877768 | $4.796280 |
| `testBenchmark_mint_08_whitelist1000Proof()` | whitelist1000 Proof | 326934 | 326934 | $0.098080 | $0.490401 | $0.980802 | $2.942406 | $4.904010 |
| `testBenchmark_mint_09_fixedPriceERC20()` | fixed Price ERC20 | 275331 | 275331 | $0.082599 | $0.412997 | $0.825993 | $2.477979 | $4.129965 |
| `testBenchmark_mint_10_fixedPriceFiveLengthRules()` | fixed Price Five Length Rules | 287207 | 287207 | $0.086162 | $0.430811 | $0.861621 | $2.584863 | $4.308105 |
| `testBenchmark_mint_11_lengthBasedFiveRules()` | length Based Five Rules | 310269 | 310269 | $0.093081 | $0.465404 | $0.930807 | $2.792421 | $4.654035 |
| `testBenchmark_mint_12_emojiOnlyPricing()` | emoji Only Pricing | 274020 | 274020 | $0.082206 | $0.411030 | $0.822060 | $2.466180 | $4.110300 |
| `testBenchmark_mint_13_numberOnlyPricing()` | number Only Pricing | 273785 | 273785 | $0.082136 | $0.410678 | $0.821355 | $2.464065 | $4.106775 |
| `testBenchmark_mint_14_erc20SplitProcessor()` | erc20 Split Processor | 366433 | 366433 | $0.109930 | $0.549650 | $1.099299 | $3.297897 | $5.496495 |
| `testBenchmark_mint_15_resolverOneRecord()` | resolver One Record | 249878 | 249878 | $0.074963 | $0.374817 | $0.749634 | $2.248902 | $3.748170 |
| `testBenchmark_mint_16_resolverThreeRecords()` | resolver Three Records | 287769 | 287769 | $0.086331 | $0.431654 | $0.863307 | $2.589921 | $4.316535 |
| `testBenchmark_mint_17_resolverFiveRecords()` | resolver Five Records | 325747 | 325747 | $0.097724 | $0.488621 | $0.977241 | $2.931723 | $4.886205 |
| `testBenchmark_mint_18_fullStackAllPoliciesPricingSplitFiveHooks()` | full Stack All Policies Pricing Split Five Hooks | 667447 | 667447 | $0.200234 | $1.001170 | $2.002341 | $6.007023 | $10.011705 |

## Policy Function Profile

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_profile_policy_00_saleWindow_checkMint()` | sale Window check Mint | 34923 | 34923 | $0.010477 | $0.052385 | $0.104769 | $0.314307 | $0.523845 |
| `testBenchmark_profile_policy_01_labelLength_checkMint()` | label Length check Mint | 35119 | 35119 | $0.010536 | $0.052679 | $0.105357 | $0.316071 | $0.526785 |
| `testBenchmark_profile_policy_02_erc20Gate_checkMint()` | erc20 Gate check Mint | 42500 | 42500 | $0.012750 | $0.063750 | $0.127500 | $0.382500 | $0.637500 |
| `testBenchmark_profile_policy_03_reservation10_checkMint()` | reservation10 check Mint | 47617 | 47617 | $0.014285 | $0.071426 | $0.142851 | $0.428553 | $0.714255 |
| `testBenchmark_profile_policy_04_reservation100_checkMint()` | reservation100 check Mint | 54808 | 54808 | $0.016442 | $0.082212 | $0.164424 | $0.493272 | $0.822120 |
| `testBenchmark_profile_policy_05_reservation200_checkMint()` | reservation200 check Mint | 57247 | 57247 | $0.017174 | $0.085871 | $0.171741 | $0.515223 | $0.858705 |
| `testBenchmark_profile_policy_06_whitelist10_checkMint()` | whitelist10 check Mint | 44754 | 44754 | $0.013426 | $0.067131 | $0.134262 | $0.402786 | $0.671310 |
| `testBenchmark_profile_policy_07_whitelist100_checkMint()` | whitelist100 check Mint | 52032 | 52032 | $0.015610 | $0.078048 | $0.156096 | $0.468288 | $0.780480 |
| `testBenchmark_profile_policy_08_whitelist1000_checkMint()` | whitelist1000 check Mint | 59285 | 59285 | $0.017785 | $0.088928 | $0.177855 | $0.533565 | $0.889275 |
| `testBenchmark_profile_policy_09_pausePolicy_checkMint()` | pause Policy check Mint | 34642 | 34642 | $0.010393 | $0.051963 | $0.103926 | $0.311778 | $0.519630 |

## Pricing Function Profile

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_profile_pricing_00_fixedDefault_quoteMint()` | fixed Default quote Mint | 33298 | 33298 | $0.009989 | $0.049947 | $0.099894 | $0.299682 | $0.499470 |
| `testBenchmark_profile_pricing_01_fixedFiveLengthRules_quoteMint()` | fixed Five Length Rules quote Mint | 45219 | 45219 | $0.013566 | $0.067828 | $0.135657 | $0.406971 | $0.678285 |
| `testBenchmark_profile_pricing_02_lengthBasedFiveRules_quoteMint()` | length Based Five Rules quote Mint | 33626 | 33626 | $0.010088 | $0.050439 | $0.100878 | $0.302634 | $0.504390 |
| `testBenchmark_profile_pricing_03_emojiOnly_quoteMint()` | emoji Only quote Mint | 32200 | 32200 | $0.009660 | $0.048300 | $0.096600 | $0.289800 | $0.483000 |
| `testBenchmark_profile_pricing_04_numberOnly_quoteMint()` | number Only quote Mint | 31898 | 31898 | $0.009569 | $0.047847 | $0.095694 | $0.287082 | $0.478470 |
| `testBenchmark_profile_pricing_05_letterOnly_quoteMint()` | letter Only quote Mint | 35897 | 35897 | $0.010769 | $0.053846 | $0.107691 | $0.323073 | $0.538455 |

## Payment, Processor, And Hook Function Profile

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_profile_hook_00_setAddrToBuyer_afterMint()` | set Addr To Buyer after Mint | 85653 | 85653 | $0.025696 | $0.128479 | $0.256959 | $0.770877 | $1.284795 |
| `testBenchmark_profile_payment_00_collectMintERC20()` | collect Mint ERC20 | 66368 | 66368 | $0.019910 | $0.099552 | $0.199104 | $0.597312 | $0.995520 |
| `testBenchmark_profile_processor_00_noop_processMint()` | noop process Mint | 44008 | 44008 | $0.013202 | $0.066012 | $0.132024 | $0.396072 | $0.660120 |
| `testBenchmark_profile_processor_01_split_processMint()` | split process Mint | 109235 | 109235 | $0.032771 | $0.163853 | $0.327705 | $0.983115 | $1.638525 |

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
