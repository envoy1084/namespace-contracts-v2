#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT="test/benchmarks/.gas-snapshot"
OUTPUT="BENCHMARKS.md"
COMPONENTS="benchmarks/gas-components.tsv"
ETH_PRICE_USD="${ETH_PRICE_USD:-3000}"

forge snapshot --match-path 'test/benchmarks/*.t.sol' --snap "$SNAPSHOT"

mkdir -p "$(dirname "$COMPONENTS")"

tmp_output="$(mktemp)"
tmp_components="$(mktemp)"
trap 'rm -f "$tmp_output" "$tmp_components"' EXIT

build_components() {
  awk -v out="$tmp_components" '
    function gas_for(name) {
      return gas_by_name[name] + 0
    }
    function emit(key, kind, source, description, gas) {
      printf "%s\t%s\t%d\t%s\t%s\n", key, kind, gas, source, description >> out
    }
    function absolute(key, kind, name, description) {
      emit(key, kind, name, description, gas_for(name))
    }
    function delta(key, kind, name, base, description) {
      emit(key, kind, name " - " base, description, gas_for(name) - gas_for(base))
    }
    $1 ~ /testBenchmark_/ {
      name = $1
      sub(/^[^:]+:/, "", name)
      sub(/\(\)$/, "", name)
      gas = $3
      gsub(/[()]/, "", gas)
      gas_by_name[name] = gas + 0
    }
    END {
      print "key\tkind\tgas\tsource\tdescription" > out

      absolute("activation.free_no_rules", "exact", "testBenchmark_activation_00_pncFreeNoRules", "Activation with no rules, no payment, no hooks.")
      absolute("activation.all_rules_split_five_resolver_writes", "exact", "testBenchmark_activation_24_pncAllRulesSplitFiveResolverWrites", "Activation with every current rule, split payment, and five resolver writes.")

      absolute("mint.free_no_rules", "exact", "testBenchmark_mint_00_pncFreeNoRules", "Controller mint with no rules, no payment, no hooks.")
      absolute("mint.fixed_erc20", "exact", "testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment", "Controller mint with fixed price rule and direct ERC20 payment.")
      absolute("mint.three_rules_erc20", "exact", "testBenchmark_mint_08_pncThreeRulesERC20PaymentNoResolver", "Controller mint with sale window, label length, fixed price, and direct ERC20 payment.")
      absolute("mint.three_rules_split_two_resolver_writes", "exact", "testBenchmark_mint_11_pncThreeRulesSplitPaymentTwoResolverWrites", "Controller mint with three rules, split payment, and two resolver writes.")
      absolute("mint.three_rules_premium_split_three_resolver_writes", "exact", "testBenchmark_mint_13_pncThreeRulesPremiumSplitPaymentThreeResolverWrites", "Controller mint with three rules, premium pricing, split payment, and three resolver writes.")
      absolute("mint.whitelist_erc20", "exact", "testBenchmark_mint_14_pncFourRulesWhitelistERC20PaymentNoResolver", "Controller mint with whitelist proof and direct ERC20 payment.")
      absolute("mint.reservation_split", "exact", "testBenchmark_mint_19_pncFiveRulesReservationDiscountSplitNoResolver", "Controller mint with reservation and token discount rules plus split payment.")
      absolute("mint.all_rules_split", "exact", "testBenchmark_mint_22_pncAllRulesSplitNoResolverWrites", "Controller mint with every current rule and split payment, no resolver writes.")
      absolute("mint.all_rules_split_three_resolver_writes", "exact", "testBenchmark_mint_23_pncAllRulesSplitThreeResolverWrites", "Controller mint with every current rule, split payment, and three resolver writes.")
      absolute("mint.all_rules_split_five_resolver_writes", "exact", "testBenchmark_mint_24_pncAllRulesSplitFiveResolverWrites", "Controller mint with every current rule, split payment, and five resolver writes.")
      absolute("renew.three_rules_erc20", "exact", "testBenchmark_renew_00_threeRulesERC20PaymentNoHook", "Controller renewal with three rules and direct ERC20 payment.")

      absolute("registry.register_no_roles", "floor", "testBenchmark_registry_00_registerNoRolesNoResolver", "Direct ENSv2 registry register with owner, no buyer roles, no resolver.")
      absolute("registry.register_buyer_roles", "floor", "testBenchmark_registry_01_registerBuyerRolesNoResolver", "Direct ENSv2 registry register with buyer roles and no resolver.")
      absolute("registry.register_buyer_roles_resolver", "floor", "testBenchmark_registry_02_registerBuyerRolesWithResolver", "Direct ENSv2 registry register with buyer roles and resolver.")
      absolute("registry.reserve_no_owner", "floor", "testBenchmark_registry_03_reserveLabelNoOwner", "Direct ENSv2 registry reserve flow with owner set to zero.")
      absolute("registry.renew_registered", "floor", "testBenchmark_registry_04_renewRegistered", "Direct ENSv2 registry renewal baseline.")

      absolute("rule.pause", "profile", "testBenchmark_profile_rule_00_pause_evaluateMint", "PauseRule evaluateMint.")
      absolute("rule.sale_window_open", "profile", "testBenchmark_profile_rule_01_saleWindowOpen_evaluateMint", "SaleWindowRule evaluateMint with open zero-bounds config.")
      absolute("rule.sale_window_bounded", "profile", "testBenchmark_profile_rule_02_saleWindowBounded_evaluateMint", "SaleWindowRule evaluateMint with active start/end bounds.")
      absolute("rule.label_length", "profile", "testBenchmark_profile_rule_03_labelLength_evaluateMint", "LabelLengthRule evaluateMint.")
      absolute("rule.fixed_price_no_overrides", "profile", "testBenchmark_profile_rule_04_fixedPriceNoLengthOverrides_evaluateMint", "FixedPriceRule with no length overrides.")
      absolute("rule.fixed_price_5_fallback", "profile", "testBenchmark_profile_rule_05_fixedPriceFiveOverridesFallback_evaluateMint", "FixedPriceRule with five overrides and fallback label.")
      absolute("rule.fixed_price_5_exact", "profile", "testBenchmark_profile_rule_06_fixedPriceFiveOverridesExact_evaluateMint", "FixedPriceRule with five overrides and exact-length hit.")
      absolute("rule.fixed_price_20_exact", "profile", "testBenchmark_profile_rule_07_fixedPriceTwentyOverridesExact_evaluateMint", "FixedPriceRule with twenty overrides and exact-length hit.")
      absolute("rule.length_premium_5", "profile", "testBenchmark_profile_rule_08_lengthPremiumFiveBuckets_evaluateMint", "LengthPremiumRule with five buckets.")
      absolute("rule.length_premium_5_fallback", "profile", "testBenchmark_profile_rule_09_lengthPremiumFiveBucketsFallback_evaluateMint", "LengthPremiumRule with five buckets and fallback bucket.")
      absolute("rule.length_premium_20", "profile", "testBenchmark_profile_rule_10_lengthPremiumTwentyBuckets_evaluateMint", "LengthPremiumRule with twenty buckets.")
      absolute("rule.token_balance_discount", "profile", "testBenchmark_profile_rule_11_tokenBalanceDiscount_evaluateMint", "TokenBalanceRule with minimum balance and discount.")
      absolute("rule.reservation_10", "profile", "testBenchmark_profile_rule_12_reservation10_evaluateMint", "ReservationRule with Merkle set size 10.")
      absolute("rule.reservation_100", "profile", "testBenchmark_profile_rule_13_reservation100_evaluateMint", "ReservationRule with Merkle set size 100.")
      absolute("rule.reservation_1000", "profile", "testBenchmark_profile_rule_14_reservation1000_evaluateMint", "ReservationRule with Merkle set size 1000.")
      absolute("rule.whitelist_10", "profile", "testBenchmark_profile_rule_15_whitelist10_evaluateMint", "WhitelistRule with Merkle set size 10.")
      absolute("rule.whitelist_100", "profile", "testBenchmark_profile_rule_16_whitelist100_evaluateMint", "WhitelistRule with Merkle set size 100.")
      absolute("rule.whitelist_1000", "profile", "testBenchmark_profile_rule_17_whitelist1000_evaluateMint", "WhitelistRule with Merkle set size 1000.")
      absolute("rule.label_class_number", "profile", "testBenchmark_profile_rule_18_labelClassNumber_evaluateMint", "LabelClassRule for numeric labels.")
      absolute("rule.label_class_letter", "profile", "testBenchmark_profile_rule_19_labelClassLetter_evaluateMint", "LabelClassRule for ASCII letter labels.")
      absolute("rule.label_class_emoji", "profile", "testBenchmark_profile_rule_20_labelClassEmoji_evaluateMint", "LabelClassRule for emoji labels.")
      absolute("rule.usd_oracle", "profile", "testBenchmark_profile_rule_21_usdOracle_evaluateMint", "USDOracleRule with Chainlink-compatible oracle.")

      absolute("payment.erc20", "profile", "testBenchmark_profile_payment_00_collectMintERC20", "Direct ERC20 transferFrom payment module.")
      absolute("payment.split_2", "profile", "testBenchmark_profile_payment_01_collectMintSplitERC20TwoRecipients", "ERC20 split payment to two recipients.")
      absolute("payment.split_3", "profile", "testBenchmark_profile_payment_02_collectMintSplitERC20ThreeRecipients", "ERC20 split payment to three recipients.")
      absolute("payment.split_5", "profile", "testBenchmark_profile_payment_03_collectMintSplitERC20FiveRecipients", "ERC20 split payment to five recipients.")

      absolute("hook.recording", "profile", "testBenchmark_profile_hook_00_recordingPostHook_afterMint", "Recording post-hook profile.")
      absolute("hook.set_addr_empty", "profile", "testBenchmark_profile_hook_01_setAddrToBuyerEmpty_afterMint", "SetAddrToBuyerHook using buyer address.")
      absolute("hook.set_addr_override", "profile", "testBenchmark_profile_hook_02_setAddrToBuyerOverride_afterMint", "SetAddrToBuyerHook using address override.")
      absolute("hook.batch_resolver_1", "profile", "testBenchmark_profile_hook_03_batchResolverHookOneWrite_afterMint", "BatchSetAddrToBuyerHook with one resolver write.")
      absolute("hook.batch_resolver_3", "profile", "testBenchmark_profile_hook_04_batchResolverHookThreeWrites_afterMint", "BatchSetAddrToBuyerHook with three resolver writes.")
      absolute("hook.batch_resolver_5", "profile", "testBenchmark_profile_hook_05_batchResolverHookFiveWrites_afterMint", "BatchSetAddrToBuyerHook with five resolver writes.")

      delta("delta.guard_rule", "delta", "testBenchmark_mint_01_pncOneGuardRuleFree", "testBenchmark_mint_00_pncFreeNoRules", "Incremental mint cost from adding one guard rule to a free mint.")
      delta("delta.fixed_erc20_sale", "delta", "testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment", "testBenchmark_mint_00_pncFreeNoRules", "Incremental mint cost from fixed-price rule plus direct ERC20 payment.")
      delta("delta.split_over_erc20", "delta", "testBenchmark_mint_03_pncOneFixedPriceRuleSplitPayment", "testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment", "Incremental mint cost from split payment instead of direct ERC20 payment.")
      delta("delta.three_rules_over_fixed_erc20", "delta", "testBenchmark_mint_08_pncThreeRulesERC20PaymentNoResolver", "testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment", "Incremental mint cost from sale window and label-length rules over fixed ERC20 sale.")
      delta("delta.whitelist_over_three_rules", "delta", "testBenchmark_mint_14_pncFourRulesWhitelistERC20PaymentNoResolver", "testBenchmark_mint_08_pncThreeRulesERC20PaymentNoResolver", "Incremental mint cost from adding whitelist proof to the common three-rule ERC20 sale.")
      delta("delta.all_rules_over_split_three_rules", "delta", "testBenchmark_mint_22_pncAllRulesSplitNoResolverWrites", "testBenchmark_mint_09_pncThreeRulesSplitPaymentNoResolver", "Incremental mint cost from all rules over three-rule split sale.")
      delta("delta.batch_resolver_three_writes", "delta", "testBenchmark_mint_23_pncAllRulesSplitThreeResolverWrites", "testBenchmark_mint_22_pncAllRulesSplitNoResolverWrites", "Incremental mint cost from three resolver writes on all-rule split sale.")
      delta("delta.batch_resolver_two_more_writes", "delta", "testBenchmark_mint_24_pncAllRulesSplitFiveResolverWrites", "testBenchmark_mint_23_pncAllRulesSplitThreeResolverWrites", "Incremental mint cost from two additional resolver writes.")
      delta("delta.all_rules_activation", "delta", "testBenchmark_activation_24_pncAllRulesSplitFiveResolverWrites", "testBenchmark_activation_00_pncFreeNoRules", "Incremental activation setup cost from all current rules, split payment, and five resolver writes.")
    }
  ' "$SNAPSHOT"
}

build_components
mv "$tmp_components" "$COMPONENTS"

{
  cat <<'MARKDOWN'
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

MARKDOWN

  echo "- ETH price: \`\$$ETH_PRICE_USD\`"
  echo "- USD cost formula: \`gasUsed * gasPriceGwei * 1e-9 * ETH_PRICE_USD\`"
  echo "- \`Gwei used\` equals gas used denominated in gwei at a 1 gwei gas price."
  echo "- Mint tables are call-only and do not include post-call test assertions."
  echo "- Direct registry baselines show the approximate ENSv2 registry floor before Namespace rule/payment/hook overhead."
  echo "- Reservation and whitelist set sizes are represented by Merkle proof depth. Activation stores one root, so activation gas is root-only."
  echo "- Component calculator estimates are additive planning aids. Prefer \`exact\` component keys when one matches your configuration; use \`profile\` keys for rough module-level sizing."
  echo "- Full end-to-end scenario benchmarks remain the source of truth for production configurations."
  echo
} >"$tmp_output"

append_table() {
  local title="$1"
  local pattern="$2"
  local strip_pattern="$3"

  {
    echo "## $title"
    echo
    echo "| Name | Scenario | Gwei used | USD @ 1 gwei |"
    echo "| --- | --- | ---: | ---: |"
  } >>"$tmp_output"

  awk -v eth="$ETH_PRICE_USD" -v pattern="$pattern" -v strip="$strip_pattern" '
    function usd(gwei) {
      return gwei * 1e-9 * eth
    }
    function humanize(value, out, i, c, prev) {
      sub(strip, "", value)
      sub(/\(\)$/, "", value)
      gsub(/_/, " ", value)
      out = substr(value, 1, 1)
      for (i = 2; i <= length(value); i++) {
        c = substr(value, i, 1)
        prev = substr(value, i - 1, 1)
        if (c ~ /[[:upper:]]/ && prev ~ /[[:lower:][:digit:]]/) {
          out = out " "
        }
        out = out c
      }
      return out
    }
    $1 ~ pattern {
      name=$1
      sub(/^[^:]+:/, "", name)
      gas=$3
      gsub(/[()]/, "", gas)
      printf "| `%s` | %s | %d | $%.6f |\n", name, humanize(name), gas, usd(gas)
    }
  ' "$SNAPSHOT" >>"$tmp_output"

  echo >>"$tmp_output"
}

append_components() {
  {
    echo "## Gas Calculator Components"
    echo
    echo "The generated component catalog lives at \`$COMPONENTS\`. Use keys from this table with \`./scripts/calculate-gas.sh\`."
    echo
    echo "| Key | Kind | Gwei used | USD @ 1 gwei | Description |"
    echo "| --- | --- | ---: | ---: | --- |"
  } >>"$tmp_output"

  awk -F '\t' -v eth="$ETH_PRICE_USD" '
    NR == 1 { next }
    {
      usd = $3 * 1e-9 * eth
      printf "| `%s` | %s | %d | $%.6f | %s |\n", $1, $2, $3, usd, $5
    }
  ' "$COMPONENTS" >>"$tmp_output"

  echo >>"$tmp_output"
}

append_component_examples() {
  {
    echo "## Calculator Examples"
    echo
    echo "| Example | Components | Estimated gas | USD @ 1 gwei |"
    echo "| --- | --- | ---: | ---: |"
  } >>"$tmp_output"

  awk -F '\t' -v eth="$ETH_PRICE_USD" '
    NR > 1 { gas[$1] = $3 + 0 }
    END {
      example("Free mint floor", "mint.free_no_rules")
      example("Fixed ERC20 sale estimate", "mint.free_no_rules delta.fixed_erc20_sale")
      example("Common three-rule ERC20 sale", "mint.three_rules_erc20")
      example("Three-rule sale plus resolver writes", "mint.three_rules_split_two_resolver_writes")
      example("All-rule split sale", "mint.all_rules_split")
      example("All-rule split sale plus resolver writes", "mint.all_rules_split delta.batch_resolver_three_writes")
    }
    function example(label, keys, parts, i, sum, usd) {
      split(keys, parts, " ")
      sum = 0
      for (i in parts) sum += gas[parts[i]]
      usd = sum * 1e-9 * eth
      printf "| %s | `%s` | %d | $%.6f |\n", label, keys, sum, usd
    }
  ' "$COMPONENTS" >>"$tmp_output"

  echo >>"$tmp_output"
}

append_table "Activation Setup Benchmarks" \
  "testBenchmark_activation_" \
  "^testBenchmark_activation_[0-9]+_pnc"

append_table "Call-Only Mint Benchmarks" \
  "testBenchmark_mint_" \
  "^testBenchmark_mint_[0-9]+_pnc"

append_table "Renewal Benchmarks" \
  "testBenchmark_renew_" \
  "^testBenchmark_renew_[0-9]+_"

append_table "Direct ENSv2 Registry Baselines" \
  "testBenchmark_registry_" \
  "^testBenchmark_registry_[0-9]+_"

append_table "Rule Function Profiles" \
  "testBenchmark_profile_rule_" \
  "^testBenchmark_profile_rule_[0-9]+_"

append_table "Payment Function Profiles" \
  "testBenchmark_profile_payment_" \
  "^testBenchmark_profile_payment_[0-9]+_"

append_table "Hook Function Profiles" \
  "testBenchmark_profile_hook_" \
  "^testBenchmark_profile_hook_[0-9]+_"

append_components
append_component_examples

cat <<'MARKDOWN' >>"$tmp_output"
## Scenario Notes

- Activations call `NamespaceController.activate` with rule, payment, and hook configuration.
- Minting benchmarks execute one call to `NamespaceController.mint` after activation setup in `setUp()`.
- Renewal executes one `NamespaceController.renew` transaction against a label minted during setup.
- Registry baselines call ENSv2 `PermissionedRegistry` directly so Namespace overhead can be separated from the registry floor.
- Rule profiles call each rule directly with realistic activation config so hotspots can be compared before optimizing internals.
- Reservation and whitelist proof scenarios use claim-based rules with Merkle proof depths represented by set size.
- Resolver record benchmarks use dedicated resolver permissions for single-write and batch-write hooks.
- Calculator estimates are planning aids. Validate important production configurations with dedicated end-to-end benchmarks.
MARKDOWN

mv "$tmp_output" "$OUTPUT"
