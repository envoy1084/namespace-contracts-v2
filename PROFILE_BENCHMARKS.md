# Namespace Profile Gas Benchmarks

Profiles measure direct module calls and supporting baselines. They are useful for spotting hot modules and building rough estimates before adding dedicated end-to-end scenarios.

Run and regenerate:

```sh
./scripts/generate-benchmarks.sh
```

Machine-readable profile report: [`benchmarks/profile-gas-report.json`](./benchmarks/profile-gas-report.json).

Profile components are also included in [`benchmarks/gas-components.tsv`](./benchmarks/gas-components.tsv) for the calculator.

Estimate arbitrary profile stacks:

```sh
./scripts/calculate-gas.sh estimate rule.sale_window_bounded rule.label_length rule.fixed_price_no_overrides payment.erc20
```

## Assumptions

- ETH price: `$3000`
- USD cost formula: `gasUsed * gasPriceGwei * 1e-9 * ETH_PRICE_USD`.
- Profile entries are standalone calls, not full Namespace mint transactions.
- Prefer exact scenario benchmarks when one matches the target configuration.

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

## Activation Setup Profiles

| Name | Scenario | Gwei used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `testBenchmark_profile_activation_hook_00_recording()` | recording | 255396 | $0.766188 |
| `testBenchmark_profile_activation_hook_01_batchResolver()` | batch Resolver | 257506 | $0.772518 |
| `testBenchmark_profile_activation_payment_00_erc20()` | erc20 | 264594 | $0.793782 |
| `testBenchmark_profile_activation_payment_01_split2()` | split2 | 312684 | $0.938052 |
| `testBenchmark_profile_activation_rule_00_pause()` | pause | 236079 | $0.708237 |
| `testBenchmark_profile_activation_rule_01_saleWindow()` | sale Window | 239050 | $0.717150 |
| `testBenchmark_profile_activation_rule_02_labelLength()` | label Length | 258991 | $0.776973 |
| `testBenchmark_profile_activation_rule_03_fixedPriceNoLengthOverrides()` | fixed Price No Length Overrides | 287068 | $0.861204 |
| `testBenchmark_profile_activation_rule_04_fixedPriceFiveOverrides()` | fixed Price Five Overrides | 383858 | $1.151574 |
| `testBenchmark_profile_activation_rule_05_fixedPriceTwentyOverrides()` | fixed Price Twenty Overrides | 537575 | $1.612725 |
| `testBenchmark_profile_activation_rule_06_lengthPremiumFiveBuckets()` | length Premium Five Buckets | 412912 | $1.238736 |
| `testBenchmark_profile_activation_rule_07_lengthPremiumTwentyBuckets()` | length Premium Twenty Buckets | 533334 | $1.600002 |
| `testBenchmark_profile_activation_rule_08_tokenBalanceDiscount()` | token Balance Discount | 305394 | $0.916182 |
| `testBenchmark_profile_activation_rule_09_reservation10()` | reservation10 | 276063 | $0.828189 |
| `testBenchmark_profile_activation_rule_10_reservation1000()` | reservation1000 | 283731 | $0.851193 |
| `testBenchmark_profile_activation_rule_11_whitelist10()` | whitelist10 | 276658 | $0.829974 |
| `testBenchmark_profile_activation_rule_12_whitelist1000()` | whitelist1000 | 284240 | $0.852720 |
| `testBenchmark_profile_activation_rule_13_labelClassNumber()` | label Class Number | 306706 | $0.920118 |
| `testBenchmark_profile_activation_rule_14_usdOracle()` | usd Oracle | 331000 | $0.993000 |

## Profile Component Keys

| Key | Category | Runtime gwei | Activation delta gwei | Description |
| --- | --- | ---: | ---: | --- |
| `rule.pause` | rule | 35729 | 36697 | PauseRule evaluateMint. |
| `rule.sale_window_open` | rule | 36007 | 39668 | SaleWindowRule evaluateMint with open zero-bounds config. |
| `rule.sale_window_bounded` | rule | 24219 | 39668 | SaleWindowRule evaluateMint with active start/end bounds. |
| `rule.label_length` | rule | 36201 | 59609 | LabelLengthRule evaluateMint. |
| `rule.fixed_price_no_overrides` | rule | 40676 | 87686 | FixedPriceRule with no length overrides. |
| `rule.fixed_price_5_fallback` | rule | 34092 | 184476 | FixedPriceRule with five overrides and fallback label. |
| `rule.fixed_price_5_exact` | rule | 34018 | 184476 | FixedPriceRule with five overrides and exact-length hit. |
| `rule.fixed_price_20_exact` | rule | 35094 | 338193 | FixedPriceRule with twenty overrides and exact-length hit. |
| `rule.length_premium_5` | rule | 31867 | 213530 | LengthPremiumRule with five buckets. |
| `rule.length_premium_5_fallback` | rule | 31905 | 213530 | LengthPremiumRule with five buckets and fallback bucket. |
| `rule.length_premium_20` | rule | 31869 | 333952 | LengthPremiumRule with twenty buckets. |
| `rule.token_balance_discount` | rule | 45731 | 106012 | TokenBalanceRule with minimum balance and discount. |
| `rule.reservation_10` | rule | 65910 | 76681 | ReservationRule with Merkle set size 10. |
| `rule.reservation_100` | rule | 73375 | n/a | ReservationRule with Merkle set size 100. |
| `rule.reservation_1000` | rule | 80795 | 84349 | ReservationRule with Merkle set size 1000. |
| `rule.whitelist_10` | rule | 67830 | 77276 | WhitelistRule with Merkle set size 10. |
| `rule.whitelist_100` | rule | 75270 | n/a | WhitelistRule with Merkle set size 100. |
| `rule.whitelist_1000` | rule | 82713 | 84858 | WhitelistRule with Merkle set size 1000. |
| `rule.label_class_number` | rule | 30146 | 107324 | LabelClassRule for numeric labels. |
| `rule.label_class_letter` | rule | 31454 | 107324 | LabelClassRule for ASCII letter labels. |
| `rule.label_class_emoji` | rule | 30651 | 107324 | LabelClassRule for emoji labels. |
| `rule.usd_oracle` | rule | 46998 | 131618 | USDOracleRule with Chainlink-compatible oracle. |
| `payment.erc20` | payment | 83127 | 65212 | Direct ERC20 transferFrom payment module. |
| `payment.split_2` | payment | 101987 | 113302 | ERC20 split payment to two recipients. |
| `payment.split_3` | payment | 130236 | n/a | ERC20 split payment to three recipients. |
| `payment.split_5` | payment | 186872 | n/a | ERC20 split payment to five recipients. |
| `hook.recording` | hook | 130739 | 56014 | Recording post-hook profile. |
| `hook.set_addr_empty` | hook | 85082 | 58124 | SetAddrToBuyerHook using buyer address. |
| `hook.set_addr_override` | hook | 89853 | 58124 | SetAddrToBuyerHook using address override. |
| `hook.batch_resolver_1` | hook | 87634 | 58124 | BatchSetAddrToBuyerHook with one resolver write. |
| `hook.batch_resolver_3` | hook | 107599 | 58124 | BatchSetAddrToBuyerHook with three resolver writes. |
| `hook.batch_resolver_5` | hook | 127553 | 58124 | BatchSetAddrToBuyerHook with five resolver writes. |
