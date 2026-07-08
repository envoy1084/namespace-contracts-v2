# Namespace Profile Gas Benchmarks

Profiles measure direct module calls and controller slice probes. Use this report to find which rules, payments, hooks, and controller steps consume the most gas.

Run and regenerate:

```sh
./scripts/generate-benchmarks.sh
```

Run slice profiles with logs:

```sh
forge test --match-contract 'Namespace(Activation|Runtime)SliceProfile' -vv
```

- ETH price: `$3000`
- USD cost formula: `gasUsed * gasPriceGwei * 1e-9 * ETH_PRICE_USD`.
- Profile benchmark wrappers pause Foundry gas metering around setup/context construction and resume only for the target module call.
- Profile entries are standalone calls, not full Namespace transactions.
- Slice model rows focus on dominant costs; small fixed overhead such as events and residual control flow is intentionally omitted.
- Variable legend: `rule_count` is configured rule modules, `post_hook_count` is configured hooks, `payment_recipients` is split-payment recipients, `resolver_writes` is packed resolver writes, and `proof_depth = ceil(log2(set_size))` for Merkle rules.

## Rule Function Profiles

| Key | Description | Gas used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `rule.pause` | PauseRule evaluateMint. | 15935 | $0.047805 |
| `rule.sale_window_open` | SaleWindowRule evaluateMint with open zero-bounds config. | 16146 | $0.048438 |
| `rule.sale_window_bounded` | SaleWindowRule evaluateMint with active start/end bounds. | 16170 | $0.048510 |
| `rule.label_length` | LabelLengthRule evaluateMint. | 16362 | $0.049086 |
| `rule.fixed_price_no_overrides` | FixedPriceRule with no length overrides. | 20715 | $0.062145 |
| `rule.fixed_price_5_fallback` | FixedPriceRule with five overrides and fallback label. | 26010 | $0.078030 |
| `rule.fixed_price_5_exact` | FixedPriceRule with five overrides and exact-length hit. | 26024 | $0.078072 |
| `rule.fixed_price_20_exact` | FixedPriceRule with twenty overrides and exact-length hit. | 27055 | $0.081165 |
| `rule.length_premium_5` | LengthPremiumRule with five buckets. | 23840 | $0.071520 |
| `rule.length_premium_5_fallback` | LengthPremiumRule with five buckets and fallback bucket. | 23967 | $0.071901 |
| `rule.length_premium_20` | LengthPremiumRule with twenty buckets. | 23820 | $0.071460 |
| `rule.token_balance_discount` | TokenBalanceRule with minimum balance and discount. | 28477 | $0.085431 |
| `rule.reservation_10` | ReservationRule with Merkle set size 10. | 20600 | $0.061800 |
| `rule.reservation_100` | ReservationRule with Merkle set size 100. | 21472 | $0.064416 |
| `rule.reservation_1000` | ReservationRule with Merkle set size 1000. | 22345 | $0.067035 |
| `rule.whitelist_10` | WhitelistRule with Merkle set size 10. | 20337 | $0.061011 |
| `rule.whitelist_100` | WhitelistRule with Merkle set size 100. | 21185 | $0.063555 |
| `rule.whitelist_1000` | WhitelistRule with Merkle set size 1000. | 22079 | $0.066237 |
| `rule.label_class_number` | LabelClassRule for numeric labels. | 22119 | $0.066357 |
| `rule.label_class_letter` | LabelClassRule for ASCII letter labels. | 23069 | $0.069207 |
| `rule.label_class_emoji` | LabelClassRule for emoji labels. | 23135 | $0.069405 |
| `rule.usd_oracle` | USDOracleRule with Chainlink-compatible oracle. | 39154 | $0.117462 |
| `rule_renew.pause` | PauseRule evaluateRenew. | 15930 | $0.047790 |
| `rule_renew.sale_window_open` | SaleWindowRule evaluateRenew with open zero-bounds config. | 16097 | $0.048291 |
| `rule_renew.sale_window_bounded` | SaleWindowRule evaluateRenew with active start/end bounds. | 16121 | $0.048363 |
| `rule_renew.label_length` | LabelLengthRule evaluateRenew. | 16309 | $0.048927 |
| `rule_renew.fixed_price_no_overrides` | FixedPriceRule renewal with no length overrides. | 20674 | $0.062022 |
| `rule_renew.fixed_price_5_fallback` | FixedPriceRule renewal with five overrides and fallback label. | 26013 | $0.078039 |
| `rule_renew.fixed_price_5_exact` | FixedPriceRule renewal with five overrides and exact-length hit. | 25939 | $0.077817 |
| `rule_renew.fixed_price_20_exact` | FixedPriceRule renewal with twenty overrides and exact-length hit. | 27017 | $0.081051 |
| `rule_renew.length_premium_5` | LengthPremiumRule renewal with five buckets. | 23773 | $0.071319 |
| `rule_renew.length_premium_5_fallback` | LengthPremiumRule renewal with five buckets and fallback bucket. | 23895 | $0.071685 |
| `rule_renew.length_premium_20` | LengthPremiumRule renewal with twenty buckets. | 23793 | $0.071379 |
| `rule_renew.token_balance_discount` | TokenBalanceRule renewal with minimum balance and discount. | 28427 | $0.085281 |
| `rule_renew.reservation_10` | ReservationRule renewal with Merkle set size 10. | 20583 | $0.061749 |
| `rule_renew.reservation_100` | ReservationRule renewal with Merkle set size 100. | 21542 | $0.064626 |
| `rule_renew.reservation_1000` | ReservationRule renewal with Merkle set size 1000. | 22367 | $0.067101 |
| `rule_renew.whitelist_10` | WhitelistRule renewal with renew checks disabled. | 16890 | $0.050670 |
| `rule_renew.whitelist_100` | WhitelistRule renewal with renew checks disabled. | 16891 | $0.050673 |
| `rule_renew.whitelist_1000` | WhitelistRule renewal with renew checks disabled. | 16912 | $0.050736 |
| `rule_renew.label_class_number` | LabelClassRule renewal for numeric labels. | 22079 | $0.066237 |
| `rule_renew.label_class_letter` | LabelClassRule renewal for ASCII letter labels. | 23053 | $0.069159 |
| `rule_renew.label_class_emoji` | LabelClassRule renewal for emoji labels. | 23091 | $0.069273 |
| `rule_renew.usd_oracle` | USDOracleRule renewal with Chainlink-compatible oracle. | 39105 | $0.117315 |

## Payment Function Profiles

| Key | Description | Gas used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `payment.erc20` | Direct ERC20 transferFrom payment module. | 56567 | $0.169701 |
| `payment.split_2` | ERC20 split payment to two recipients. | 88629 | $0.265887 |
| `payment.split_3` | ERC20 split payment to three recipients. | 118538 | $0.355614 |
| `payment.split_5` | ERC20 split payment to five recipients. | 178449 | $0.535347 |
| `payment_renew.erc20` | Direct ERC20 transferFrom renewal payment. | 56565 | $0.169695 |
| `payment_renew.split_2` | ERC20 renewal split payment to two recipients. | 88494 | $0.265482 |
| `payment_renew.split_3` | ERC20 renewal split payment to three recipients. | 118428 | $0.355284 |
| `payment_renew.split_5` | ERC20 renewal split payment to five recipients. | 178382 | $0.535146 |

## Hook Function Profiles

| Key | Description | Gas used | USD @ 1 gwei |
| --- | --- | ---: | ---: |
| `hook.recording` | Recording post-hook profile. | 105976 | $0.317928 |
| `hook.set_addr_empty` | SetAddrToBuyerHook using buyer address. | 60126 | $0.180378 |
| `hook.set_addr_override` | SetAddrToBuyerHook using address override. | 60290 | $0.180870 |
| `hook.batch_resolver_1` | BatchSetAddrToBuyerHook with one resolver write. | 60295 | $0.180885 |
| `hook.batch_resolver_3` | BatchSetAddrToBuyerHook with three resolver writes. | 75247 | $0.225741 |
| `hook.batch_resolver_5` | BatchSetAddrToBuyerHook with five resolver writes. | 90230 | $0.270690 |
| `hook_renew.recording` | Recording post-hook afterRenew profile. | 105830 | $0.317490 |
| `hook_renew.set_addr` | SetAddrToBuyerHook afterRenew no-op profile. | 14662 | $0.043986 |
| `hook_renew.batch_resolver` | BatchSetAddrToBuyerHook afterRenew no-op profile. | 14706 | $0.044118 |

## Activation Logical Slice Model

| Key | Logical slice | Gas formula / driver |
| --- | --- | --- |
| `slice.activation.namespace_discovery` | Resolve and prove the ENSv2 namespace registry for the activated name. | ~42.7k fixed for `alice.eth`; varies with name depth and Universal Resolver implementation. |
| `slice.activation.precondition_checks` | Validate duration bounds, payment module approval, owner admin, controller roles, and unused activation id. | ~12.1k + ~4.7k * `has_payment_module`. |
| `slice.activation.store_module_lists` | Persist configured rule and post-hook module references. | ~0.6k if empty; if `rule_count > 1`, about ~0.6k + ~11.4k * `rule_count`; if `post_hook_count > 1`, add the packed hook-list SSTORE2 write. |
| `slice.activation.store_activation_record` | Write activation owner, registries, namespace identity, label, resolver, bounds, payment, and module refs. | ~186k + ~19.9k * `has_resolver` + ~19.9k * `has_payment_or_module_refs`. |
| `slice.activation.configure_modules` | Call modules so they store activation-scoped params. | ~0.8k + sum(`configure(rule_i)`) + `configure(payment_module)` if set + sum(`configure(hook_i)`). |

## Mint Logical Slice Model

| Key | Logical slice | Gas formula / driver |
| --- | --- | --- |
| `slice.mint.activation_and_namespace_checks` | Load activation, check active status, prove namespace currentness, owner admin, duration, and runtime data lengths. | ~34.1k fixed per mint. |
| `slice.mint.label_context_and_tracking` | Hash label, construct MintContext, and store label -> activation id for renewal checks. | ~29.8k fixed per newly minted label. |
| `slice.mint.rule_engine` | Evaluate configured rule modules and apply price effects in phase order. | ~0.5k if `rule_count = 0`; otherwise SSTORE2 read when `rule_count > 1` + sum(`evaluateMint(rule_i, runtimeData_i)`) + output checks. Merkle rules add roughly ~2.5k * `proof_depth` inside that rule. |
| `slice.mint.registry_register` | Call official ENSv2 PermissionedRegistry.register. | ~105k-156k per mint depending buyer roles and resolver write path. |
| `slice.mint.payment_collection` | Collect payment if the final rule price is nonzero. | ~0.3k if free; direct ERC20 ~85k; split ERC20 ~= ~45.8k + ~30k * `payment_recipients`. |
| `slice.mint.post_hooks` | Run configured post-mint hooks. | ~0.4k if `post_hook_count = 0`; otherwise sum(`afterMint(hook_i)`). Batch resolver hook ~= ~77.7k + ~9.7k * `resolver_writes`. |

## Renew Logical Slice Model

| Key | Logical slice | Gas formula / driver |
| --- | --- | --- |
| `slice.renew.activation_and_namespace_checks` | Load activation, check active status, prove namespace currentness, owner admin, duration, and runtime data lengths. | ~34.1k fixed per renewal. |
| `slice.renew.label_state_and_context` | Read label state, verify activation ownership, compute new expiry, and construct RenewContext. | ~14.2k fixed per renewal. |
| `slice.renew.rule_engine` | Evaluate configured renewal rule modules and apply price effects in phase order. | ~0.5k if `rule_count = 0`; otherwise SSTORE2 read when `rule_count > 1` + sum(`evaluateRenew(rule_i, runtimeData_i)`) + output checks. Merkle renewal rules add roughly ~2.5k * `proof_depth` when enabled. |
| `slice.renew.registry_renew` | Call official ENSv2 PermissionedRegistry.renew. | ~15.2k fixed when the registry state is warm in the controller flow. |
| `slice.renew.payment_collection` | Collect renewal payment if the final rule price is nonzero. | ~0.3k if free; direct ERC20 ~81k; split ERC20 ~= ~43.5k + ~30k * `payment_recipients`. |
| `slice.renew.post_hooks` | Run configured post-renew hooks. | ~0.4k if `post_hook_count = 0`; otherwise sum(`afterRenew(hook_i)`). Current resolver hooks are no-op on renew, so most cost is hook dispatch. |
