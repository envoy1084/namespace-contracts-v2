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
- Resolver record benchmarks use `BatchSetAddrToBuyerHook` for multi-record scenarios so one hook module can execute multiple resolver writes.

## Activation Benchmarks

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_activation_00_freeNoPolicies()` | free No Policies | 187490 | 187490 | $0.056247 | $0.281235 | $0.562470 | $1.687410 | $2.812350 |
| `testBenchmark_activation_01_twoPoliciesSaleAndLength()` | two Policies Sale And Length | 309838 | 309838 | $0.092951 | $0.464757 | $0.929514 | $2.788542 | $4.647570 |
| `testBenchmark_activation_02_threePoliciesWithERC20Gate()` | three Policies With ERC20 Gate | 377753 | 377753 | $0.113326 | $0.566630 | $1.133259 | $3.399777 | $5.666295 |
| `testBenchmark_activation_03_fourPoliciesReservation10()` | four Policies Reservation10 | 428077 | 428077 | $0.128423 | $0.642116 | $1.284231 | $3.852693 | $6.421155 |
| `testBenchmark_activation_04_fourPoliciesReservation100()` | four Policies Reservation100 | 430182 | 430182 | $0.129055 | $0.645273 | $1.290546 | $3.871638 | $6.452730 |
| `testBenchmark_activation_05_fourPoliciesReservation200()` | four Policies Reservation200 | 430842 | 430842 | $0.129253 | $0.646263 | $1.292526 | $3.877578 | $6.462630 |
| `testBenchmark_activation_06_fivePoliciesWhitelist10()` | five Policies Whitelist10 | 496979 | 496979 | $0.149094 | $0.745469 | $1.490937 | $4.472811 | $7.454685 |
| `testBenchmark_activation_07_fivePoliciesWhitelist100()` | five Policies Whitelist100 | 499006 | 499006 | $0.149702 | $0.748509 | $1.497018 | $4.491054 | $7.485090 |
| `testBenchmark_activation_08_fivePoliciesWhitelist1000()` | five Policies Whitelist1000 | 501022 | 501022 | $0.150307 | $0.751533 | $1.503066 | $4.509198 | $7.515330 |
| `testBenchmark_activation_09_fixedPriceFiveLengthRules()` | fixed Price Five Length Rules | 438365 | 438365 | $0.131510 | $0.657548 | $1.315095 | $3.945285 | $6.575475 |
| `testBenchmark_activation_10_lengthBasedFiveRules()` | length Based Five Rules | 466076 | 466076 | $0.139823 | $0.699114 | $1.398228 | $4.194684 | $6.991140 |
| `testBenchmark_activation_11_emojiOnlyPricing()` | emoji Only Pricing | 336741 | 336741 | $0.101022 | $0.505112 | $1.010223 | $3.030669 | $5.051115 |
| `testBenchmark_activation_12_numberOnlyPricing()` | number Only Pricing | 336765 | 336765 | $0.101030 | $0.505148 | $1.010295 | $3.030885 | $5.051475 |
| `testBenchmark_activation_13_compositePolicyCompositePricingDirectSplitFiveResolverWrites()` | composite Policy Composite Pricing Direct Split Five Resolver Writes | 893764 | 893764 | $0.268129 | $1.340646 | $2.681292 | $8.043876 | $13.406460 |

## Minting Benchmarks

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_mint_00_freeNoPolicies()` | free No Policies | 183331 | 183331 | $0.054999 | $0.274997 | $0.549993 | $1.649979 | $2.749965 |
| `testBenchmark_mint_01_twoPoliciesSaleAndLength()` | two Policies Sale And Length | 216260 | 216260 | $0.064878 | $0.324390 | $0.648780 | $1.946340 | $3.243900 |
| `testBenchmark_mint_02_threePoliciesWithERC20Gate()` | three Policies With ERC20 Gate | 238863 | 238863 | $0.071659 | $0.358295 | $0.716589 | $2.149767 | $3.582945 |
| `testBenchmark_mint_03_reservation10Proof()` | reservation10 Proof | 274880 | 274880 | $0.082464 | $0.412320 | $0.824640 | $2.473920 | $4.123200 |
| `testBenchmark_mint_04_reservation100Proof()` | reservation100 Proof | 281805 | 281805 | $0.084542 | $0.422708 | $0.845415 | $2.536245 | $4.227075 |
| `testBenchmark_mint_05_reservation200Proof()` | reservation200 Proof | 284089 | 284089 | $0.085227 | $0.426133 | $0.852267 | $2.556801 | $4.261335 |
| `testBenchmark_mint_06_whitelist10Proof()` | whitelist10 Proof | 299248 | 299248 | $0.089774 | $0.448872 | $0.897744 | $2.693232 | $4.488720 |
| `testBenchmark_mint_07_whitelist100Proof()` | whitelist100 Proof | 306130 | 306130 | $0.091839 | $0.459195 | $0.918390 | $2.755170 | $4.591950 |
| `testBenchmark_mint_08_whitelist1000Proof()` | whitelist1000 Proof | 313051 | 313051 | $0.093915 | $0.469577 | $0.939153 | $2.817459 | $4.695765 |
| `testBenchmark_mint_09_fixedPriceERC20()` | fixed Price ERC20 | 257284 | 257284 | $0.077185 | $0.385926 | $0.771852 | $2.315556 | $3.859260 |
| `testBenchmark_mint_10_fixedPriceFiveLengthRules()` | fixed Price Five Length Rules | 262531 | 262531 | $0.078759 | $0.393797 | $0.787593 | $2.362779 | $3.937965 |
| `testBenchmark_mint_11_lengthBasedFiveRules()` | length Based Five Rules | 292826 | 292826 | $0.087848 | $0.439239 | $0.878478 | $2.635434 | $4.392390 |
| `testBenchmark_mint_12_emojiOnlyPricing()` | emoji Only Pricing | 255790 | 255790 | $0.076737 | $0.383685 | $0.767370 | $2.302110 | $3.836850 |
| `testBenchmark_mint_13_numberOnlyPricing()` | number Only Pricing | 255345 | 255345 | $0.076604 | $0.383018 | $0.766035 | $2.298105 | $3.830175 |
| `testBenchmark_mint_14_erc20SplitProcessor()` | erc20 Split Processor | 357991 | 357991 | $0.107397 | $0.536987 | $1.073973 | $3.221919 | $5.369865 |
| `testBenchmark_mint_15_resolverOneRecord()` | resolver One Record | 243283 | 243283 | $0.072985 | $0.364924 | $0.729849 | $2.189547 | $3.649245 |
| `testBenchmark_mint_16_resolverThreeRecords()` | resolver Three Records | 263396 | 263396 | $0.079019 | $0.395094 | $0.790188 | $2.370564 | $3.950940 |
| `testBenchmark_mint_17_resolverFiveRecords()` | resolver Five Records | 283320 | 283320 | $0.084996 | $0.424980 | $0.849960 | $2.549880 | $4.249800 |
| `testBenchmark_mint_18_fullStackCompositePolicyCompositePricingDirectSplitFiveResolverWrites()` | full Stack Composite Policy Composite Pricing Direct Split Five Resolver Writes | 498340 | 498340 | $0.149502 | $0.747510 | $1.495020 | $4.485060 | $7.475100 |

## Policy Function Profile

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_profile_policy_00_saleWindow_checkMint()` | sale Window check Mint | 34810 | 34810 | $0.010443 | $0.052215 | $0.104430 | $0.313290 | $0.522150 |
| `testBenchmark_profile_policy_01_labelLength_checkMint()` | label Length check Mint | 34980 | 34980 | $0.010494 | $0.052470 | $0.104940 | $0.314820 | $0.524700 |
| `testBenchmark_profile_policy_02_erc20Gate_checkMint()` | erc20 Gate check Mint | 42389 | 42389 | $0.012717 | $0.063584 | $0.127167 | $0.381501 | $0.635835 |
| `testBenchmark_profile_policy_03_reservation10_checkMint()` | reservation10 check Mint | 46446 | 46446 | $0.013934 | $0.069669 | $0.139338 | $0.418014 | $0.696690 |
| `testBenchmark_profile_policy_04_reservation100_checkMint()` | reservation100 check Mint | 53424 | 53424 | $0.016027 | $0.080136 | $0.160272 | $0.480816 | $0.801360 |
| `testBenchmark_profile_policy_05_reservation200_checkMint()` | reservation200 check Mint | 55770 | 55770 | $0.016731 | $0.083655 | $0.167310 | $0.501930 | $0.836550 |
| `testBenchmark_profile_policy_06_whitelist10_checkMint()` | whitelist10 check Mint | 44057 | 44057 | $0.013217 | $0.066086 | $0.132171 | $0.396513 | $0.660855 |
| `testBenchmark_profile_policy_07_whitelist100_checkMint()` | whitelist100 check Mint | 51034 | 51034 | $0.015310 | $0.076551 | $0.153102 | $0.459306 | $0.765510 |
| `testBenchmark_profile_policy_08_whitelist1000_checkMint()` | whitelist1000 check Mint | 58030 | 58030 | $0.017409 | $0.087045 | $0.174090 | $0.522270 | $0.870450 |
| `testBenchmark_profile_policy_09_pausePolicy_checkMint()` | pause Policy check Mint | 34573 | 34573 | $0.010372 | $0.051860 | $0.103719 | $0.311157 | $0.518595 |

## Pricing Function Profile

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_profile_pricing_00_fixedDefault_quoteMint()` | fixed Default quote Mint | 33233 | 33233 | $0.009970 | $0.049850 | $0.099699 | $0.299097 | $0.498495 |
| `testBenchmark_profile_pricing_01_fixedFiveLengthRules_quoteMint()` | fixed Five Length Rules quote Mint | 38503 | 38503 | $0.011551 | $0.057755 | $0.115509 | $0.346527 | $0.577545 |
| `testBenchmark_profile_pricing_02_lengthBasedFiveRules_quoteMint()` | length Based Five Rules quote Mint | 35994 | 35994 | $0.010798 | $0.053991 | $0.107982 | $0.323946 | $0.539910 |
| `testBenchmark_profile_pricing_03_emojiOnly_quoteMint()` | emoji Only quote Mint | 31916 | 31916 | $0.009575 | $0.047874 | $0.095748 | $0.287244 | $0.478740 |
| `testBenchmark_profile_pricing_04_numberOnly_quoteMint()` | number Only quote Mint | 31404 | 31404 | $0.009421 | $0.047106 | $0.094212 | $0.282636 | $0.471060 |
| `testBenchmark_profile_pricing_05_letterOnly_quoteMint()` | letter Only quote Mint | 34521 | 34521 | $0.010356 | $0.051782 | $0.103563 | $0.310689 | $0.517815 |

## Payment, Processor, And Hook Function Profile

| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `testBenchmark_profile_hook_00_setAddrToBuyer_afterMint()` | set Addr To Buyer after Mint | 85162 | 85162 | $0.025549 | $0.127743 | $0.255486 | $0.766458 | $1.277430 |
| `testBenchmark_profile_payment_00_collectMintERC20()` | collect Mint ERC20 | 66116 | 66116 | $0.019835 | $0.099174 | $0.198348 | $0.595044 | $0.991740 |
| `testBenchmark_profile_processor_00_noop_processMint()` | noop process Mint | 43890 | 43890 | $0.013167 | $0.065835 | $0.131670 | $0.395010 | $0.658350 |
| `testBenchmark_profile_processor_01_split_processMint()` | split process Mint | 109003 | 109003 | $0.032701 | $0.163505 | $0.327009 | $0.981027 | $1.635045 |

## Scenario Notes

| Area | Notes |
| --- | --- |
| Activations | Activation benchmarks call `NamespaceController.activate` with the named policy, pricing, processor, and hook configuration. |
| Minting | Minting benchmarks execute one `NamespaceController.mint` transaction after activation setup in `setUp()`. |
| Reservations | Reservation proof scenarios use proofs for the named set size. Larger sets increase proof depth and mint gas, while activation gas remains root-only. |
| Whitelists | Whitelist scenarios use `ACCOUNT_LABEL` leaves so both buyer and requested label are proven. |
| Resolver hooks | 1, 3, and 5 record scenarios benchmark resolver addr writes; multi-record scenarios use one batched post-hook module. |
| Full stack | The full-stack benchmark uses `CompositeMintPolicy` for sale window, label length, ERC20 gate, reservation, and whitelist checks, `CompositePricing` for class, fixed, and length pricing, `ERC20SplitPaymentModule` for direct ERC20 split settlement, and `BatchSetAddrToBuyerHook` for five resolver writes. |
| Function profiles | Profile rows call individual module functions directly with realistic activation config so hotspots can be compared before optimizing internals. |
