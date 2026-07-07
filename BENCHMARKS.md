# Namespace Issuance Gas Benchmarks

These benchmarks measure activation setup, exact call-only minting, renewal, direct ENSv2 registry baselines, and per-module profiles for the rule-based Namespace subname issuance architecture.

The minting benchmarks are call-only for the Namespace mint path: buyer calls `NamespaceController.mint`, configured rules evaluate eligibility and price effects, the official ENSv2 `PermissionedRegistry` mints the label, the payment module settles funds, and post-hooks run when configured. They intentionally do not include post-mint test assertions.

Reference: [Foundry gas tracking](https://www.getfoundry.sh/forge/gas-tracking).

Run and regenerate this file:

```sh
./scripts/generate-benchmarks.sh
```

Use the calculator:

```sh
./scripts/calculate-gas.sh list
./scripts/calculate-gas.sh mint.free_no_rules delta.fixed_erc20_sale
./scripts/calculate-gas.sh --gas-price-gwei 5 mint.three_rules_erc20 hook.batch_resolver_3
```

## Assumptions

- ETH price: `$3000`
- USD cost formula: `gasUsed * gasPriceGwei * 1e-9 * ETH_PRICE_USD`
- `Gwei used` equals gas used denominated in gwei at a 1 gwei gas price.
- Mint tables are call-only and do not include post-call test assertions.
- Direct registry baselines show the approximate ENSv2 registry floor before Namespace rule/payment/hook overhead.
- Reservation and whitelist set sizes are represented by Merkle proof depth. Activation stores one root, so activation gas is root-only.
- Component calculator estimates are additive planning aids. Prefer `exact` component keys when one matches your configuration; use `profile` keys for rough module-level sizing.
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

## Rule Function Profiles

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `testBenchmark_profile_rule_00_pause_evaluateMint()` | pause evaluate Mint | 35729 | $0.107187 |
| `testBenchmark_profile_rule_01_saleWindowOpen_evaluateMint()` | sale Window Open evaluate Mint | 36007 | $0.108021 |
| `testBenchmark_profile_rule_02_saleWindowBounded_evaluateMint()` | sale Window Bounded evaluate Mint | 24219 | $0.072657 |
| `testBenchmark_profile_rule_03_labelLength_evaluateMint()` | label Length evaluate Mint | 36201 | $0.108603 |
| `testBenchmark_profile_rule_04_fixedPriceNoLengthOverrides_evaluateMint()` | fixed Price No Length Overrides evaluate Mint | 40676 | $0.122028 |
| `testBenchmark_profile_rule_05_fixedPriceFiveOverridesFallback_evaluateMint()` | fixed Price Five Overrides Fallback evaluate Mint | 34092 | $0.102276 |
| `testBenchmark_profile_rule_06_fixedPriceFiveOverridesExact_evaluateMint()` | fixed Price Five Overrides Exact evaluate Mint | 34018 | $0.102054 |
| `testBenchmark_profile_rule_07_fixedPriceTwentyOverridesExact_evaluateMint()` | fixed Price Twenty Overrides Exact evaluate Mint | 35094 | $0.105282 |
| `testBenchmark_profile_rule_08_lengthPremiumFiveBuckets_evaluateMint()` | length Premium Five Buckets evaluate Mint | 31867 | $0.095601 |
| `testBenchmark_profile_rule_09_lengthPremiumFiveBucketsFallback_evaluateMint()` | length Premium Five Buckets Fallback evaluate Mint | 31905 | $0.095715 |
| `testBenchmark_profile_rule_10_lengthPremiumTwentyBuckets_evaluateMint()` | length Premium Twenty Buckets evaluate Mint | 31869 | $0.095607 |
| `testBenchmark_profile_rule_11_tokenBalanceDiscount_evaluateMint()` | token Balance Discount evaluate Mint | 45731 | $0.137193 |
| `testBenchmark_profile_rule_12_reservation10_evaluateMint()` | reservation10 evaluate Mint | 65910 | $0.197730 |
| `testBenchmark_profile_rule_13_reservation100_evaluateMint()` | reservation100 evaluate Mint | 73375 | $0.220125 |
| `testBenchmark_profile_rule_14_reservation1000_evaluateMint()` | reservation1000 evaluate Mint | 80795 | $0.242385 |
| `testBenchmark_profile_rule_15_whitelist10_evaluateMint()` | whitelist10 evaluate Mint | 67830 | $0.203490 |
| `testBenchmark_profile_rule_16_whitelist100_evaluateMint()` | whitelist100 evaluate Mint | 75270 | $0.225810 |
| `testBenchmark_profile_rule_17_whitelist1000_evaluateMint()` | whitelist1000 evaluate Mint | 82713 | $0.248139 |
| `testBenchmark_profile_rule_18_labelClassNumber_evaluateMint()` | label Class Number evaluate Mint | 30146 | $0.090438 |
| `testBenchmark_profile_rule_19_labelClassLetter_evaluateMint()` | label Class Letter evaluate Mint | 31454 | $0.094362 |
| `testBenchmark_profile_rule_20_labelClassEmoji_evaluateMint()` | label Class Emoji evaluate Mint | 30651 | $0.091953 |
| `testBenchmark_profile_rule_21_usdOracle_evaluateMint()` | usd Oracle evaluate Mint | 46998 | $0.140994 |

## Payment Function Profiles

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `testBenchmark_profile_payment_00_collectMintERC20()` | collect Mint ERC20 | 83127 | $0.249381 |
| `testBenchmark_profile_payment_01_collectMintSplitERC20TwoRecipients()` | collect Mint Split ERC20 Two Recipients | 101987 | $0.305961 |
| `testBenchmark_profile_payment_02_collectMintSplitERC20ThreeRecipients()` | collect Mint Split ERC20 Three Recipients | 130236 | $0.390708 |
| `testBenchmark_profile_payment_03_collectMintSplitERC20FiveRecipients()` | collect Mint Split ERC20 Five Recipients | 186872 | $0.560616 |

## Hook Function Profiles

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `testBenchmark_profile_hook_00_recordingPostHook_afterMint()` | recording Post Hook after Mint | 130739 | $0.392217 |
| `testBenchmark_profile_hook_01_setAddrToBuyerEmpty_afterMint()` | set Addr To Buyer Empty after Mint | 85082 | $0.255246 |
| `testBenchmark_profile_hook_02_setAddrToBuyerOverride_afterMint()` | set Addr To Buyer Override after Mint | 89853 | $0.269559 |
| `testBenchmark_profile_hook_03_batchResolverHookOneWrite_afterMint()` | batch Resolver Hook One Write after Mint | 87634 | $0.262902 |
| `testBenchmark_profile_hook_04_batchResolverHookThreeWrites_afterMint()` | batch Resolver Hook Three Writes after Mint | 107599 | $0.322797 |
| `testBenchmark_profile_hook_05_batchResolverHookFiveWrites_afterMint()` | batch Resolver Hook Five Writes after Mint | 127553 | $0.382659 |

## Gas Calculator Components

The generated component catalog lives at `benchmarks/gas-components.tsv`. Use keys from this table with `./scripts/calculate-gas.sh`.

| Key | Kind | Gwei used | USD @ 1 gwei | Description |
| --- | --- | ---: | ---: | --- |
| `activation.free_no_rules` | exact | 199382 | $0.598146 | Activation with no rules, no payment, no hooks. |
| `activation.all_rules_split_five_resolver_writes` | exact | 1352999 | $4.058997 | Activation with every current rule, split payment, and five resolver writes. |
| `mint.free_no_rules` | exact | 164818 | $0.494454 | Controller mint with no rules, no payment, no hooks. |
| `mint.fixed_erc20` | exact | 223261 | $0.669783 | Controller mint with fixed price rule and direct ERC20 payment. |
| `mint.three_rules_erc20` | exact | 260191 | $0.780573 | Controller mint with sale window, label length, fixed price, and direct ERC20 payment. |
| `mint.three_rules_split_two_resolver_writes` | exact | 365174 | $1.095522 | Controller mint with three rules, split payment, and two resolver writes. |
| `mint.three_rules_premium_split_three_resolver_writes` | exact | 381738 | $1.145214 | Controller mint with three rules, premium pricing, split payment, and three resolver writes. |
| `mint.whitelist_erc20` | exact | 318031 | $0.954093 | Controller mint with whitelist proof and direct ERC20 payment. |
| `mint.reservation_split` | exact | 372106 | $1.116318 | Controller mint with reservation and token discount rules plus split payment. |
| `mint.all_rules_split` | exact | 571297 | $1.713891 | Controller mint with every current rule and split payment, no resolver writes. |
| `mint.all_rules_split_three_resolver_writes` | exact | 653255 | $1.959765 | Controller mint with every current rule, split payment, and three resolver writes. |
| `mint.all_rules_split_five_resolver_writes` | exact | 673172 | $2.019516 | Controller mint with every current rule, split payment, and five resolver writes. |
| `renew.three_rules_erc20` | exact | 151488 | $0.454464 | Controller renewal with three rules and direct ERC20 payment. |
| `registry.register_no_roles` | floor | 76072 | $0.228216 | Direct ENSv2 registry register with owner, no buyer roles, no resolver. |
| `registry.register_buyer_roles` | floor | 123378 | $0.370134 | Direct ENSv2 registry register with buyer roles and no resolver. |
| `registry.register_buyer_roles_resolver` | floor | 127383 | $0.382149 | Direct ENSv2 registry register with buyer roles and resolver. |
| `registry.reserve_no_owner` | floor | 45141 | $0.135423 | Direct ENSv2 registry reserve flow with owner set to zero. |
| `registry.renew_registered` | floor | 27975 | $0.083925 | Direct ENSv2 registry renewal baseline. |
| `rule.pause` | profile | 35729 | $0.107187 | PauseRule evaluateMint. |
| `rule.sale_window_open` | profile | 36007 | $0.108021 | SaleWindowRule evaluateMint with open zero-bounds config. |
| `rule.sale_window_bounded` | profile | 24219 | $0.072657 | SaleWindowRule evaluateMint with active start/end bounds. |
| `rule.label_length` | profile | 36201 | $0.108603 | LabelLengthRule evaluateMint. |
| `rule.fixed_price_no_overrides` | profile | 40676 | $0.122028 | FixedPriceRule with no length overrides. |
| `rule.fixed_price_5_fallback` | profile | 34092 | $0.102276 | FixedPriceRule with five overrides and fallback label. |
| `rule.fixed_price_5_exact` | profile | 34018 | $0.102054 | FixedPriceRule with five overrides and exact-length hit. |
| `rule.fixed_price_20_exact` | profile | 35094 | $0.105282 | FixedPriceRule with twenty overrides and exact-length hit. |
| `rule.length_premium_5` | profile | 31867 | $0.095601 | LengthPremiumRule with five buckets. |
| `rule.length_premium_5_fallback` | profile | 31905 | $0.095715 | LengthPremiumRule with five buckets and fallback bucket. |
| `rule.length_premium_20` | profile | 31869 | $0.095607 | LengthPremiumRule with twenty buckets. |
| `rule.token_balance_discount` | profile | 45731 | $0.137193 | TokenBalanceRule with minimum balance and discount. |
| `rule.reservation_10` | profile | 65910 | $0.197730 | ReservationRule with Merkle set size 10. |
| `rule.reservation_100` | profile | 73375 | $0.220125 | ReservationRule with Merkle set size 100. |
| `rule.reservation_1000` | profile | 80795 | $0.242385 | ReservationRule with Merkle set size 1000. |
| `rule.whitelist_10` | profile | 67830 | $0.203490 | WhitelistRule with Merkle set size 10. |
| `rule.whitelist_100` | profile | 75270 | $0.225810 | WhitelistRule with Merkle set size 100. |
| `rule.whitelist_1000` | profile | 82713 | $0.248139 | WhitelistRule with Merkle set size 1000. |
| `rule.label_class_number` | profile | 30146 | $0.090438 | LabelClassRule for numeric labels. |
| `rule.label_class_letter` | profile | 31454 | $0.094362 | LabelClassRule for ASCII letter labels. |
| `rule.label_class_emoji` | profile | 30651 | $0.091953 | LabelClassRule for emoji labels. |
| `rule.usd_oracle` | profile | 46998 | $0.140994 | USDOracleRule with Chainlink-compatible oracle. |
| `payment.erc20` | profile | 83127 | $0.249381 | Direct ERC20 transferFrom payment module. |
| `payment.split_2` | profile | 101987 | $0.305961 | ERC20 split payment to two recipients. |
| `payment.split_3` | profile | 130236 | $0.390708 | ERC20 split payment to three recipients. |
| `payment.split_5` | profile | 186872 | $0.560616 | ERC20 split payment to five recipients. |
| `hook.recording` | profile | 130739 | $0.392217 | Recording post-hook profile. |
| `hook.set_addr_empty` | profile | 85082 | $0.255246 | SetAddrToBuyerHook using buyer address. |
| `hook.set_addr_override` | profile | 89853 | $0.269559 | SetAddrToBuyerHook using address override. |
| `hook.batch_resolver_1` | profile | 87634 | $0.262902 | BatchSetAddrToBuyerHook with one resolver write. |
| `hook.batch_resolver_3` | profile | 107599 | $0.322797 | BatchSetAddrToBuyerHook with three resolver writes. |
| `hook.batch_resolver_5` | profile | 127553 | $0.382659 | BatchSetAddrToBuyerHook with five resolver writes. |
| `delta.guard_rule` | delta | 18732 | $0.056196 | Incremental mint cost from adding one guard rule to a free mint. |
| `delta.fixed_erc20_sale` | delta | 58443 | $0.175329 | Incremental mint cost from fixed-price rule plus direct ERC20 payment. |
| `delta.split_over_erc20` | delta | 30736 | $0.092208 | Incremental mint cost from split payment instead of direct ERC20 payment. |
| `delta.three_rules_over_fixed_erc20` | delta | 36930 | $0.110790 | Incremental mint cost from sale window and label-length rules over fixed ERC20 sale. |
| `delta.whitelist_over_three_rules` | delta | 57840 | $0.173520 | Incremental mint cost from adding whitelist proof to the common three-rule ERC20 sale. |
| `delta.all_rules_over_split_three_rules` | delta | 280328 | $0.840984 | Incremental mint cost from all rules over three-rule split sale. |
| `delta.batch_resolver_three_writes` | delta | 81958 | $0.245874 | Incremental mint cost from three resolver writes on all-rule split sale. |
| `delta.batch_resolver_two_more_writes` | delta | 19917 | $0.059751 | Incremental mint cost from two additional resolver writes. |
| `delta.all_rules_activation` | delta | 1153617 | $3.460851 | Incremental activation setup cost from all current rules, split payment, and five resolver writes. |

## Calculator Examples

| Example | Components | Estimated gas | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| Free mint floor | `mint.free_no_rules` | 164818 | $0.494454 |
| Fixed ERC20 sale estimate | `mint.free_no_rules delta.fixed_erc20_sale` | 223261 | $0.669783 |
| Common three-rule ERC20 sale | `mint.three_rules_erc20` | 260191 | $0.780573 |
| Three-rule sale plus resolver writes | `mint.three_rules_split_two_resolver_writes` | 365174 | $1.095522 |
| All-rule split sale | `mint.all_rules_split` | 571297 | $1.713891 |
| All-rule split sale plus resolver writes | `mint.all_rules_split delta.batch_resolver_three_writes` | 653255 | $1.959765 |

## Scenario Notes

- Activations call `NamespaceController.activate` with rule, payment, and hook configuration.
- Minting benchmarks execute one call to `NamespaceController.mint` after activation setup in `setUp()`.
- Renewal executes one `NamespaceController.renew` transaction against a label minted during setup.
- Registry baselines call ENSv2 `PermissionedRegistry` directly so Namespace overhead can be separated from the registry floor.
- Rule profiles call each rule directly with realistic activation config so hotspots can be compared before optimizing internals.
- Reservation and whitelist proof scenarios use claim-based rules with Merkle proof depths represented by set size.
- Resolver record benchmarks use dedicated resolver permissions for single-write and batch-write hooks.
- Calculator estimates are planning aids. Validate important production configurations with dedicated end-to-end benchmarks.
