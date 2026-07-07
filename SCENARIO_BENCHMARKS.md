# Namespace Scenario Gas Benchmarks

Scenario benchmarks measure full activation, mint, renewal, and registry-floor flows for common Namespace configurations.

Run and regenerate:

```sh
./scripts/generate-benchmarks.sh
```

## Assumptions

- ETH price: `$3000`
- Mint scenarios are call-only and do not include post-call test assertions.
- Direct registry baselines show the approximate ENSv2 floor before Namespace rule/payment/hook overhead.
- Full end-to-end scenario benchmarks remain the source of truth for production configurations.

## Activation Setup Benchmarks

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `testBenchmark_activation_00_pncFreeNoRules()` | Free No Rules | 199382 | $0.598146 |
| `testBenchmark_activation_01_pncOneGuardRuleFree()` | One Guard Rule Free | 241561 | $0.724683 |
| `testBenchmark_activation_02_pncOneFixedPriceRuleERC20Payment()` | One Fixed Price Rule ERC20 Payment | 353113 | $1.059339 |
| `testBenchmark_activation_03_pncOneFixedPriceRuleSplitPayment()` | One Fixed Price Rule Split Payment | 401314 | $1.203942 |
| `testBenchmark_activation_04_pncTwoRulesFreeNoResolver()` | Two Rules Free No Resolver | 324272 | $0.972816 |
| `testBenchmark_activation_05_pncTwoRulesERC20PaymentNoResolver()` | Two Rules ERC20 Payment No Resolver | 415853 | $1.247559 |
| `testBenchmark_activation_06_pncTwoRulesSplitPaymentNoResolver()` | Two Rules Split Payment No Resolver | 464033 | $1.392099 |
| `testBenchmark_activation_07_pncTwoEligibilityPriceRulesERC20Payment()` | Two Eligibility Price Rules ERC20 Payment | 435843 | $1.307529 |
| `testBenchmark_activation_08_pncThreeRulesERC20PaymentNoResolver()` | Three Rules ERC20 Payment No Resolver | 460880 | $1.382640 |
| `testBenchmark_activation_09_pncThreeRulesSplitPaymentNoResolver()` | Three Rules Split Payment No Resolver | 509063 | $1.527189 |
| `testBenchmark_activation_10_pncThreeRulesERC20PaymentRecordingHook()` | Three Rules ERC20 Payment Recording Hook | 517198 | $1.551594 |
| `testBenchmark_activation_11_pncThreeRulesSplitPaymentTwoResolverWrites()` | Three Rules Split Payment Two Resolver Writes | 567533 | $1.702599 |
| `testBenchmark_activation_12_pncThreeRulesPremiumERC20PaymentNoResolver()` | Three Rules Premium ERC20 Payment No Resolver | 612803 | $1.838409 |
| `testBenchmark_activation_13_pncThreeRulesPremiumSplitPaymentThreeResolverWrites()` | Three Rules Premium Split Payment Three Resolver Writes | 719501 | $2.158503 |
| `testBenchmark_activation_14_pncFourRulesWhitelistERC20PaymentNoResolver()` | Four Rules Whitelist ERC20 Payment No Resolver | 523510 | $1.570530 |
| `testBenchmark_activation_15_pncFourRulesWhitelistSplitPaymentTwoResolverWrites()` | Four Rules Whitelist Split Payment Two Resolver Writes | 630240 | $1.890720 |
| `testBenchmark_activation_16_pncFourRulesPremiumERC20PaymentNoResolver()` | Four Rules Premium ERC20 Payment No Resolver | 657754 | $1.973262 |
| `testBenchmark_activation_17_pncFourRulesPremiumSplitPaymentThreeResolverWrites()` | Four Rules Premium Split Payment Three Resolver Writes | 764475 | $2.293425 |
| `testBenchmark_activation_18_pncFiveRulesWhitelistPremiumSplitNoResolver()` | Five Rules Whitelist Premium Split No Resolver | 768666 | $2.305998 |
| `testBenchmark_activation_19_pncFiveRulesReservationDiscountSplitNoResolver()` | Five Rules Reservation Discount Split No Resolver | 658561 | $1.975683 |
| `testBenchmark_activation_20_pncSixRulesPauseWhitelistReservationSplitNoResolver()` | Six Rules Pause Whitelist Reservation Split No Resolver | 652021 | $1.956063 |
| `testBenchmark_activation_21_pncSixRulesWhitelistReservationSplitThreeResolverWrites()` | Six Rules Whitelist Reservation Split Three Resolver Writes | 777812 | $2.333436 |
| `testBenchmark_activation_22_pncAllRulesSplitNoResolverWrites()` | All Rules Split No Resolver Writes | 1294462 | $3.883386 |
| `testBenchmark_activation_23_pncAllRulesSplitThreeResolverWrites()` | All Rules Split Three Resolver Writes | 1352957 | $4.058871 |
| `testBenchmark_activation_24_pncAllRulesSplitFiveResolverWrites()` | All Rules Split Five Resolver Writes | 1352999 | $4.058997 |

## Call-Only Mint Benchmarks

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `testBenchmark_mint_00_pncFreeNoRules()` | Free No Rules | 162444 | $0.487332 |
| `testBenchmark_mint_01_pncOneGuardRuleFree()` | One Guard Rule Free | 181187 | $0.543561 |
| `testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment()` | One Fixed Price Rule ERC20 Payment | 220761 | $0.662283 |
| `testBenchmark_mint_03_pncOneFixedPriceRuleSplitPayment()` | One Fixed Price Rule Split Payment | 251151 | $0.753453 |
| `testBenchmark_mint_04_pncTwoRulesFreeNoResolver()` | Two Rules Free No Resolver | 201414 | $0.604242 |
| `testBenchmark_mint_05_pncTwoRulesERC20PaymentNoResolver()` | Two Rules ERC20 Payment No Resolver | 240751 | $0.722253 |
| `testBenchmark_mint_06_pncTwoRulesSplitPaymentNoResolver()` | Two Rules Split Payment No Resolver | 271189 | $0.813567 |
| `testBenchmark_mint_07_pncTwoEligibilityPriceRulesERC20Payment()` | Two Eligibility Price Rules ERC20 Payment | 240992 | $0.722976 |
| `testBenchmark_mint_08_pncThreeRulesERC20PaymentNoResolver()` | Three Rules ERC20 Payment No Resolver | 257786 | $0.773358 |
| `testBenchmark_mint_09_pncThreeRulesSplitPaymentNoResolver()` | Three Rules Split Payment No Resolver | 288218 | $0.864654 |
| `testBenchmark_mint_10_pncThreeRulesERC20PaymentRecordingHook()` | Three Rules ERC20 Payment Recording Hook | 387612 | $1.162836 |
| `testBenchmark_mint_11_pncThreeRulesSplitPaymentTwoResolverWrites()` | Three Rules Split Payment Two Resolver Writes | 364400 | $1.093200 |
| `testBenchmark_mint_12_pncThreeRulesPremiumERC20PaymentNoResolver()` | Three Rules Premium ERC20 Payment No Resolver | 266578 | $0.799734 |
| `testBenchmark_mint_13_pncThreeRulesPremiumSplitPaymentThreeResolverWrites()` | Three Rules Premium Split Payment Three Resolver Writes | 380800 | $1.142400 |
| `testBenchmark_mint_14_pncFourRulesWhitelistERC20PaymentNoResolver()` | Four Rules Whitelist ERC20 Payment No Resolver | 315626 | $0.946878 |
| `testBenchmark_mint_15_pncFourRulesWhitelistSplitPaymentTwoResolverWrites()` | Four Rules Whitelist Split Payment Two Resolver Writes | 422266 | $1.266798 |
| `testBenchmark_mint_16_pncFourRulesPremiumERC20PaymentNoResolver()` | Four Rules Premium ERC20 Payment No Resolver | 283607 | $0.850821 |
| `testBenchmark_mint_17_pncFourRulesPremiumSplitPaymentThreeResolverWrites()` | Four Rules Premium Split Payment Three Resolver Writes | 397835 | $1.193505 |
| `testBenchmark_mint_18_pncFiveRulesWhitelistPremiumSplitNoResolver()` | Five Rules Whitelist Premium Split No Resolver | 371912 | $1.115736 |
| `testBenchmark_mint_19_pncFiveRulesReservationDiscountSplitNoResolver()` | Five Rules Reservation Discount Split No Resolver | 369355 | $1.108065 |
| `testBenchmark_mint_20_pncSixRulesPauseWhitelistReservationSplitNoResolver()` | Six Rules Pause Whitelist Reservation Split No Resolver | 420089 | $1.260267 |
| `testBenchmark_mint_21_pncSixRulesWhitelistReservationSplitThreeResolverWrites()` | Six Rules Whitelist Reservation Split Three Resolver Writes | 511002 | $1.533006 |
| `testBenchmark_mint_22_pncAllRulesSplitNoResolverWrites()` | All Rules Split No Resolver Writes | 568613 | $1.705839 |
| `testBenchmark_mint_23_pncAllRulesSplitThreeResolverWrites()` | All Rules Split Three Resolver Writes | 652384 | $1.957152 |
| `testBenchmark_mint_24_pncAllRulesSplitFiveResolverWrites()` | All Rules Split Five Resolver Writes | 671973 | $2.015919 |

## Renewal Benchmarks

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `testBenchmark_renew_00_threeRulesERC20PaymentNoHook()` | three Rules ERC20 Payment No Hook | 149083 | $0.447249 |

## Direct ENSv2 Registry Baselines

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `testBenchmark_registry_00_registerNoRolesNoResolver()` | register No Roles No Resolver | 76072 | $0.228216 |
| `testBenchmark_registry_01_registerBuyerRolesNoResolver()` | register Buyer Roles No Resolver | 123378 | $0.370134 |
| `testBenchmark_registry_02_registerBuyerRolesWithResolver()` | register Buyer Roles With Resolver | 127383 | $0.382149 |
| `testBenchmark_registry_03_reserveLabelNoOwner()` | reserve Label No Owner | 45141 | $0.135423 |
| `testBenchmark_registry_04_renewRegistered()` | renew Registered | 27975 | $0.083925 |

## Exact And Delta Component Keys

| Key | Kind | Gwei used | Description |
| --- | --- | ---: | --- |
| `activation.free_no_rules` | exact | 199382 | Activation with no rules, no payment, no hooks. |
| `activation.all_rules_split_five_resolver_writes` | exact | 1352999 | Activation with every current rule, split payment, and five resolver writes. |
| `mint.free_no_rules` | exact | 162444 | Controller mint with no rules, no payment, no hooks. |
| `mint.fixed_erc20` | exact | 220761 | Controller mint with fixed price rule and direct ERC20 payment. |
| `mint.three_rules_erc20` | exact | 257786 | Controller mint with sale window, label length, fixed price, and direct ERC20 payment. |
| `mint.three_rules_split_two_resolver_writes` | exact | 364400 | Controller mint with three rules, split payment, and two resolver writes. |
| `mint.three_rules_premium_split_three_resolver_writes` | exact | 380800 | Controller mint with three rules, premium pricing, split payment, and three resolver writes. |
| `mint.whitelist_erc20` | exact | 315626 | Controller mint with whitelist proof and direct ERC20 payment. |
| `mint.reservation_split` | exact | 369355 | Controller mint with reservation and token discount rules plus split payment. |
| `mint.all_rules_split` | exact | 568613 | Controller mint with every current rule and split payment, no resolver writes. |
| `mint.all_rules_split_three_resolver_writes` | exact | 652384 | Controller mint with every current rule, split payment, and three resolver writes. |
| `mint.all_rules_split_five_resolver_writes` | exact | 671973 | Controller mint with every current rule, split payment, and five resolver writes. |
| `renew.three_rules_erc20` | exact | 149083 | Controller renewal with three rules and direct ERC20 payment. |
| `registry.register_no_roles` | floor | 76072 | Direct ENSv2 registry register with owner, no buyer roles, no resolver. |
| `registry.register_buyer_roles` | floor | 123378 | Direct ENSv2 registry register with buyer roles and no resolver. |
| `registry.register_buyer_roles_resolver` | floor | 127383 | Direct ENSv2 registry register with buyer roles and resolver. |
| `registry.reserve_no_owner` | floor | 45141 | Direct ENSv2 registry reserve flow with owner set to zero. |
| `registry.renew_registered` | floor | 27975 | Direct ENSv2 registry renewal baseline. |
| `delta.guard_rule` | delta | 18743 | Incremental mint cost from adding one guard rule to a free mint. |
| `delta.fixed_erc20_sale` | delta | 58317 | Incremental mint cost from fixed-price rule plus direct ERC20 payment. |
| `delta.split_over_erc20` | delta | 30390 | Incremental mint cost from split payment instead of direct ERC20 payment. |
| `delta.three_rules_over_fixed_erc20` | delta | 37025 | Incremental mint cost from sale window and label-length rules over fixed ERC20 sale. |
| `delta.whitelist_over_three_rules` | delta | 57840 | Incremental mint cost from adding whitelist proof to the common three-rule ERC20 sale. |
| `delta.all_rules_over_split_three_rules` | delta | 280395 | Incremental mint cost from all rules over three-rule split sale. |
| `delta.batch_resolver_three_writes` | delta | 83771 | Incremental mint cost from three resolver writes on all-rule split sale. |
| `delta.batch_resolver_two_more_writes` | delta | 19589 | Incremental mint cost from two additional resolver writes. |
| `delta.all_rules_activation` | delta | 1153617 | Incremental activation setup cost from all current rules, split payment, and five resolver writes. |

## Calculator Examples

| Example | Components | Estimated gas | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| Free mint floor | `mint.free_no_rules` | 162444 | $0.487332 |
| Fixed ERC20 sale estimate | `mint.free_no_rules delta.fixed_erc20_sale` | 220761 | $0.662283 |
| Common three-rule ERC20 sale | `mint.three_rules_erc20` | 257786 | $0.773358 |
| Three-rule sale plus resolver writes | `mint.three_rules_split_two_resolver_writes` | 364400 | $1.093200 |
| All-rule split sale | `mint.all_rules_split` | 568613 | $1.705839 |
| All-rule split sale plus resolver writes | `mint.all_rules_split delta.batch_resolver_three_writes` | 652384 | $1.957152 |
