# Namespace Issuance Gas Benchmarks

These benchmarks measure activation setup, end-to-end minting, renewal, and individual module function costs for the rule-based Namespace subname issuance architecture.

The minting benchmarks are end to end for the Namespace mint path: buyer calls `NamespaceController.mint`, configured rules evaluate eligibility and price effects, the payment module settles funds, the official ENSv2 `PermissionedRegistry` mints the label, and post-hooks run when configured.

Reference: [Foundry gas tracking](https://www.getfoundry.sh/forge/gas-tracking).

Run and regenerate this file:

```sh
./scripts/generate-benchmarks.sh
```

## Assumptions

- ETH price: `$3000`
- USD cost formula: `gasUsed * gasPriceGwei * 1e-9 * ETH_PRICE_USD`
- `Gwei used` equals gas used denominated in gwei at a 1 gwei gas price.
- Reservation and whitelist set sizes are represented by Merkle proof depth. Activation stores one root, so activation gas is root-only.
- Resolver record benchmarks use `BatchSetAddrToBuyerHook` so one hook module can execute multiple resolver writes.
- Component estimates are benchmark deltas. They are useful for planning arbitrary combinations, but full end-to-end permutations remain the source of truth.
- Benchmark tables intentionally use four columns: name, scenario, gwei used, and USD at a 1 gwei gas price.

## Activation Benchmarks

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

## Minting Benchmarks

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `testBenchmark_mint_00_pncFreeNoRules()` | Free No Rules | 171303 | $0.513909 |
| `testBenchmark_mint_01_pncOneGuardRuleFree()` | One Guard Rule Free | 189755 | $0.569265 |
| `testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment()` | One Fixed Price Rule ERC20 Payment | 228753 | $0.686259 |
| `testBenchmark_mint_03_pncOneFixedPriceRuleSplitPayment()` | One Fixed Price Rule Split Payment | 259489 | $0.778467 |
| `testBenchmark_mint_04_pncTwoRulesFreeNoResolver()` | Two Rules Free No Resolver | 210133 | $0.630399 |
| `testBenchmark_mint_05_pncTwoRulesERC20PaymentNoResolver()` | Two Rules ERC20 Payment No Resolver | 248900 | $0.746700 |
| `testBenchmark_mint_06_pncTwoRulesSplitPaymentNoResolver()` | Two Rules Split Payment No Resolver | 279678 | $0.839034 |
| `testBenchmark_mint_07_pncTwoEligibilityPriceRulesERC20Payment()` | Two Eligibility Price Rules ERC20 Payment | 249135 | $0.747405 |
| `testBenchmark_mint_08_pncThreeRulesERC20PaymentNoResolver()` | Three Rules ERC20 Payment No Resolver | 265912 | $0.797736 |
| `testBenchmark_mint_09_pncThreeRulesSplitPaymentNoResolver()` | Three Rules Split Payment No Resolver | 296690 | $0.890070 |
| `testBenchmark_mint_10_pncThreeRulesERC20PaymentRecordingHook()` | Three Rules ERC20 Payment Recording Hook | 393455 | $1.180365 |
| `testBenchmark_mint_11_pncThreeRulesSplitPaymentTwoResolverWrites()` | Three Rules Split Payment Two Resolver Writes | 370895 | $1.112685 |
| `testBenchmark_mint_12_pncThreeRulesPremiumERC20PaymentNoResolver()` | Three Rules Premium ERC20 Payment No Resolver | 273988 | $0.821964 |
| `testBenchmark_mint_13_pncThreeRulesPremiumSplitPaymentThreeResolverWrites()` | Three Rules Premium Split Payment Three Resolver Writes | 386743 | $1.160229 |
| `testBenchmark_mint_14_pncFourRulesWhitelistERC20PaymentNoResolver()` | Four Rules Whitelist ERC20 Payment No Resolver | 323735 | $0.971205 |
| `testBenchmark_mint_15_pncFourRulesWhitelistSplitPaymentTwoResolverWrites()` | Four Rules Whitelist Split Payment Two Resolver Writes | 428744 | $1.286232 |
| `testBenchmark_mint_16_pncFourRulesPremiumERC20PaymentNoResolver()` | Four Rules Premium ERC20 Payment No Resolver | 291000 | $0.873000 |
| `testBenchmark_mint_17_pncFourRulesPremiumSplitPaymentThreeResolverWrites()` | Four Rules Premium Split Payment Three Resolver Writes | 403761 | $1.211283 |
| `testBenchmark_mint_18_pncFiveRulesWhitelistPremiumSplitNoResolver()` | Five Rules Whitelist Premium Split No Resolver | 379634 | $1.138902 |
| `testBenchmark_mint_19_pncFiveRulesReservationDiscountSplitNoResolver()` | Five Rules Reservation Discount Split No Resolver | 376203 | $1.128609 |
| `testBenchmark_mint_20_pncSixRulesPauseWhitelistReservationSplitNoResolver()` | Six Rules Pause Whitelist Reservation Split No Resolver | 427652 | $1.282956 |
| `testBenchmark_mint_21_pncSixRulesWhitelistReservationSplitThreeResolverWrites()` | Six Rules Whitelist Reservation Split Three Resolver Writes | 516020 | $1.548060 |
| `testBenchmark_mint_22_pncAllRulesSplitNoResolverWrites()` | All Rules Split No Resolver Writes | 573161 | $1.719483 |
| `testBenchmark_mint_23_pncAllRulesSplitThreeResolverWrites()` | All Rules Split Three Resolver Writes | 655119 | $1.965357 |
| `testBenchmark_mint_24_pncAllRulesSplitFiveResolverWrites()` | All Rules Split Five Resolver Writes | 675036 | $2.025108 |

## Renewal Benchmarks

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `testBenchmark_renew_00_threeRulesERC20PaymentNoHook()` | three Rules ERC20 Payment No Hook | 150759 | $0.452277 |

## Rule Function Profile

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `testBenchmark_profile_rule_00_pause_evaluateMint()` | pause evaluate Mint | 35792 | $0.107376 |
| `testBenchmark_profile_rule_01_saleWindow_evaluateMint()` | sale Window evaluate Mint | 36050 | $0.108150 |
| `testBenchmark_profile_rule_02_labelLength_evaluateMint()` | label Length evaluate Mint | 36197 | $0.108591 |
| `testBenchmark_profile_rule_03_fixedPriceNoLengthOverrides_evaluateMint()` | fixed Price No Length Overrides evaluate Mint | 40675 | $0.122025 |
| `testBenchmark_profile_rule_04_fixedPriceFiveLengthOverrides_evaluateMint()` | fixed Price Five Length Overrides evaluate Mint | 34092 | $0.102276 |
| `testBenchmark_profile_rule_05_fixedPriceTwentyLengthOverrides_evaluateMint()` | fixed Price Twenty Length Overrides evaluate Mint | 35051 | $0.105153 |
| `testBenchmark_profile_rule_06_lengthPremiumFiveBuckets_evaluateMint()` | length Premium Five Buckets evaluate Mint | 31950 | $0.095850 |
| `testBenchmark_profile_rule_07_lengthPremiumTwentyBuckets_evaluateMint()` | length Premium Twenty Buckets evaluate Mint | 31891 | $0.095673 |
| `testBenchmark_profile_rule_08_tokenBalanceDiscount_evaluateMint()` | token Balance Discount evaluate Mint | 45773 | $0.137319 |
| `testBenchmark_profile_rule_09_reservation10_evaluateMint()` | reservation10 evaluate Mint | 65955 | $0.197865 |
| `testBenchmark_profile_rule_10_reservation1000_evaluateMint()` | reservation1000 evaluate Mint | 80815 | $0.242445 |
| `testBenchmark_profile_rule_11_whitelist10_evaluateMint()` | whitelist10 evaluate Mint | 67851 | $0.203553 |
| `testBenchmark_profile_rule_12_whitelist1000_evaluateMint()` | whitelist1000 evaluate Mint | 82713 | $0.248139 |
| `testBenchmark_profile_rule_13_labelClassNumber_evaluateMint()` | label Class Number evaluate Mint | 30144 | $0.090432 |
| `testBenchmark_profile_rule_14_usdOracle_evaluateMint()` | usd Oracle evaluate Mint | 47000 | $0.141000 |

## Payment And Hook Function Profile

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `testBenchmark_profile_hook_00_recordingPostHook_afterMint()` | recording Post Hook after Mint | 130696 | $0.392088 |
| `testBenchmark_profile_hook_01_batchResolverHookThreeWrites_afterMint()` | batch Resolver Hook Three Writes after Mint | 107643 | $0.322929 |
| `testBenchmark_profile_hook_02_batchResolverHookFiveWrites_afterMint()` | batch Resolver Hook Five Writes after Mint | 127532 | $0.382596 |
| `testBenchmark_profile_payment_00_collectMintERC20()` | collect Mint ERC20 | 83171 | $0.249513 |
| `testBenchmark_profile_payment_01_collectMintSplitERC20()` | collect Mint Split ERC20 | 113953 | $0.341859 |

## Component Cost Model

Use this section to estimate a custom configuration before adding a dedicated end-to-end benchmark. Start with the closest end-to-end baseline, add relevant deltas, then validate important production configurations with a real benchmark.

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| No-rule mint baseline | Absolute `mint_00_pncFreeNoRules` | 171303 | $0.513909 |
| One guard rule | Delta: `mint_01` - `mint_00` | +18452 | $0.055356 |
| One fixed-price ERC20 sale | Delta: `mint_02` - `mint_00` | +57450 | $0.172350 |
| ERC20 split instead of direct payment | Delta: `mint_03` - `mint_02` | +30736 | $0.092208 |
| Second free eligibility rule | Delta: `mint_04` - `mint_01` | +20378 | $0.061134 |
| Three-rule paid stack | Delta: `mint_08` - `mint_02` | +37159 | $0.111477 |
| Recording post-hook | Delta: `mint_10` - `mint_08` | +127543 | $0.382629 |
| All-rule stack before resolver writes | Delta: `mint_22` - `mint_09` | +276471 | $0.829413 |
| Batch resolver hook, three writes | Delta: `mint_23` - `mint_22` | +81958 | $0.245874 |
| Two additional resolver writes | Delta: `mint_24` - `mint_23` | +19917 | $0.059751 |
| Extra resolver write | Derived: (`mint_24` - `mint_23`) / 2 | +9958 | $0.029874 |
| All-rule activation config | Delta: `activation_24` - `activation_00` | +1153617 | $3.460851 |
| PauseRule.evaluateMint | Absolute profile | 35792 | $0.107376 |
| SaleWindowRule.evaluateMint | Absolute profile | 36050 | $0.108150 |
| LabelLengthRule.evaluateMint | Absolute profile | 36197 | $0.108591 |
| FixedPriceRule.evaluateMint, no overrides | Absolute profile | 40675 | $0.122025 |
| FixedPriceRule.evaluateMint, 5 overrides | Absolute profile | 34092 | $0.102276 |
| FixedPriceRule.evaluateMint, 20 overrides | Absolute profile | 35051 | $0.105153 |
| LengthPremiumRule.evaluateMint, 5 buckets | Absolute profile | 31950 | $0.095850 |
| LengthPremiumRule.evaluateMint, 20 buckets | Absolute profile | 31891 | $0.095673 |
| TokenBalanceRule.evaluateMint | Absolute profile | 45773 | $0.137319 |
| ReservationRule proof depth 4 | Absolute profile | 65955 | $0.197865 |
| ReservationRule proof depth 10 | Absolute profile | 80815 | $0.242445 |
| Reservation proof sibling | Derived per additional Merkle sibling | +2476 | $0.007428 |
| WhitelistRule proof depth 4 | Absolute profile | 67851 | $0.203553 |
| WhitelistRule proof depth 10 | Absolute profile | 82713 | $0.248139 |
| Whitelist proof sibling | Derived per additional Merkle sibling | +2477 | $0.007431 |
| LabelClassRule.evaluateMint | Absolute profile | 30144 | $0.090432 |
| USDOracleRule.evaluateMint | Absolute profile | 47000 | $0.141000 |
| ERC20Payment.collectMint | Absolute profile | 83171 | $0.249513 |
| ERC20SplitPayment.collectMint | Absolute profile | 113953 | $0.341859 |
| Split payment premium | Derived: `profile_payment_01` - `profile_payment_00` | +30782 | $0.092346 |
| RecordingPostHook.afterMint | Absolute profile | 130696 | $0.392088 |
| Batch resolver hook, three writes | Absolute profile | 107643 | $0.322929 |
| Batch resolver hook, five writes | Absolute profile | 127532 | $0.382596 |

## Scenario Notes

- Activations call `NamespaceController.activate` with rule, payment, and hook configuration.
- Minting executes one `NamespaceController.mint` transaction after activation setup in `setUp()`.
- Renewal executes one `NamespaceController.renew` transaction against a label minted during setup.
- Rule profiles call each rule directly with realistic activation config so hotspots can be compared before optimizing internals.
- Reservation and whitelist proof scenarios use claim-based rules with Merkle proof depths represented by set size.
- Resolver record benchmarks use one batched post-hook module for multiple addr writes.
- Component estimates use benchmark deltas and direct module profiles so arbitrary combinations can be estimated before adding a dedicated benchmark.
