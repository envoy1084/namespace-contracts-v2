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
| `testBenchmark_mint_00_pncFreeNoRules()` | Free No Rules | 164818 | $0.494454 |
| `testBenchmark_mint_01_pncOneGuardRuleFree()` | One Guard Rule Free | 183550 | $0.550650 |
| `testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment()` | One Fixed Price Rule ERC20 Payment | 223261 | $0.669783 |
| `testBenchmark_mint_03_pncOneFixedPriceRuleSplitPayment()` | One Fixed Price Rule Split Payment | 253997 | $0.761991 |
| `testBenchmark_mint_04_pncTwoRulesFreeNoResolver()` | Two Rules Free No Resolver | 203682 | $0.611046 |
| `testBenchmark_mint_05_pncTwoRulesERC20PaymentNoResolver()` | Two Rules ERC20 Payment No Resolver | 243156 | $0.729468 |
| `testBenchmark_mint_06_pncTwoRulesSplitPaymentNoResolver()` | Two Rules Split Payment No Resolver | 273940 | $0.821820 |
| `testBenchmark_mint_07_pncTwoEligibilityPriceRulesERC20Payment()` | Two Eligibility Price Rules ERC20 Payment | 243397 | $0.730191 |
| `testBenchmark_mint_08_pncThreeRulesERC20PaymentNoResolver()` | Three Rules ERC20 Payment No Resolver | 260191 | $0.780573 |
| `testBenchmark_mint_09_pncThreeRulesSplitPaymentNoResolver()` | Three Rules Split Payment No Resolver | 290969 | $0.872907 |
| `testBenchmark_mint_10_pncThreeRulesERC20PaymentRecordingHook()` | Three Rules ERC20 Payment Recording Hook | 387734 | $1.163202 |
| `testBenchmark_mint_11_pncThreeRulesSplitPaymentTwoResolverWrites()` | Three Rules Split Payment Two Resolver Writes | 365174 | $1.095522 |
| `testBenchmark_mint_12_pncThreeRulesPremiumERC20PaymentNoResolver()` | Three Rules Premium ERC20 Payment No Resolver | 268983 | $0.806949 |
| `testBenchmark_mint_13_pncThreeRulesPremiumSplitPaymentThreeResolverWrites()` | Three Rules Premium Split Payment Three Resolver Writes | 381738 | $1.145214 |
| `testBenchmark_mint_14_pncFourRulesWhitelistERC20PaymentNoResolver()` | Four Rules Whitelist ERC20 Payment No Resolver | 318031 | $0.954093 |
| `testBenchmark_mint_15_pncFourRulesWhitelistSplitPaymentTwoResolverWrites()` | Four Rules Whitelist Split Payment Two Resolver Writes | 423040 | $1.269120 |
| `testBenchmark_mint_16_pncFourRulesPremiumERC20PaymentNoResolver()` | Four Rules Premium ERC20 Payment No Resolver | 286012 | $0.858036 |
| `testBenchmark_mint_17_pncFourRulesPremiumSplitPaymentThreeResolverWrites()` | Four Rules Premium Split Payment Three Resolver Writes | 398773 | $1.196319 |
| `testBenchmark_mint_18_pncFiveRulesWhitelistPremiumSplitNoResolver()` | Five Rules Whitelist Premium Split No Resolver | 374663 | $1.123989 |
| `testBenchmark_mint_19_pncFiveRulesReservationDiscountSplitNoResolver()` | Five Rules Reservation Discount Split No Resolver | 372106 | $1.116318 |
| `testBenchmark_mint_20_pncSixRulesPauseWhitelistReservationSplitNoResolver()` | Six Rules Pause Whitelist Reservation Split No Resolver | 422840 | $1.268520 |
| `testBenchmark_mint_21_pncSixRulesWhitelistReservationSplitThreeResolverWrites()` | Six Rules Whitelist Reservation Split Three Resolver Writes | 511940 | $1.535820 |
| `testBenchmark_mint_22_pncAllRulesSplitNoResolverWrites()` | All Rules Split No Resolver Writes | 571297 | $1.713891 |
| `testBenchmark_mint_23_pncAllRulesSplitThreeResolverWrites()` | All Rules Split Three Resolver Writes | 653255 | $1.959765 |
| `testBenchmark_mint_24_pncAllRulesSplitFiveResolverWrites()` | All Rules Split Five Resolver Writes | 673172 | $2.019516 |

## Renewal Benchmarks

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `testBenchmark_renew_00_threeRulesERC20PaymentNoHook()` | three Rules ERC20 Payment No Hook | 151488 | $0.454464 |

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
| `mint.free_no_rules` | exact | 164818 | Controller mint with no rules, no payment, no hooks. |
| `mint.fixed_erc20` | exact | 223261 | Controller mint with fixed price rule and direct ERC20 payment. |
| `mint.three_rules_erc20` | exact | 260191 | Controller mint with sale window, label length, fixed price, and direct ERC20 payment. |
| `mint.three_rules_split_two_resolver_writes` | exact | 365174 | Controller mint with three rules, split payment, and two resolver writes. |
| `mint.three_rules_premium_split_three_resolver_writes` | exact | 381738 | Controller mint with three rules, premium pricing, split payment, and three resolver writes. |
| `mint.whitelist_erc20` | exact | 318031 | Controller mint with whitelist proof and direct ERC20 payment. |
| `mint.reservation_split` | exact | 372106 | Controller mint with reservation and token discount rules plus split payment. |
| `mint.all_rules_split` | exact | 571297 | Controller mint with every current rule and split payment, no resolver writes. |
| `mint.all_rules_split_three_resolver_writes` | exact | 653255 | Controller mint with every current rule, split payment, and three resolver writes. |
| `mint.all_rules_split_five_resolver_writes` | exact | 673172 | Controller mint with every current rule, split payment, and five resolver writes. |
| `renew.three_rules_erc20` | exact | 151488 | Controller renewal with three rules and direct ERC20 payment. |
| `registry.register_no_roles` | floor | 76072 | Direct ENSv2 registry register with owner, no buyer roles, no resolver. |
| `registry.register_buyer_roles` | floor | 123378 | Direct ENSv2 registry register with buyer roles and no resolver. |
| `registry.register_buyer_roles_resolver` | floor | 127383 | Direct ENSv2 registry register with buyer roles and resolver. |
| `registry.reserve_no_owner` | floor | 45141 | Direct ENSv2 registry reserve flow with owner set to zero. |
| `registry.renew_registered` | floor | 27975 | Direct ENSv2 registry renewal baseline. |
| `delta.guard_rule` | delta | 18732 | Incremental mint cost from adding one guard rule to a free mint. |
| `delta.fixed_erc20_sale` | delta | 58443 | Incremental mint cost from fixed-price rule plus direct ERC20 payment. |
| `delta.split_over_erc20` | delta | 30736 | Incremental mint cost from split payment instead of direct ERC20 payment. |
| `delta.three_rules_over_fixed_erc20` | delta | 36930 | Incremental mint cost from sale window and label-length rules over fixed ERC20 sale. |
| `delta.whitelist_over_three_rules` | delta | 57840 | Incremental mint cost from adding whitelist proof to the common three-rule ERC20 sale. |
| `delta.all_rules_over_split_three_rules` | delta | 280328 | Incremental mint cost from all rules over three-rule split sale. |
| `delta.batch_resolver_three_writes` | delta | 81958 | Incremental mint cost from three resolver writes on all-rule split sale. |
| `delta.batch_resolver_two_more_writes` | delta | 19917 | Incremental mint cost from two additional resolver writes. |
| `delta.all_rules_activation` | delta | 1153617 | Incremental activation setup cost from all current rules, split payment, and five resolver writes. |

## Calculator Examples

| Example | Components | Estimated gas | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| Free mint floor | `mint.free_no_rules` | 164818 | $0.494454 |
| Fixed ERC20 sale estimate | `mint.free_no_rules delta.fixed_erc20_sale` | 223261 | $0.669783 |
| Common three-rule ERC20 sale | `mint.three_rules_erc20` | 260191 | $0.780573 |
| Three-rule sale plus resolver writes | `mint.three_rules_split_two_resolver_writes` | 365174 | $1.095522 |
| All-rule split sale | `mint.all_rules_split` | 571297 | $1.713891 |
| All-rule split sale plus resolver writes | `mint.all_rules_split delta.batch_resolver_three_writes` | 653255 | $1.959765 |
