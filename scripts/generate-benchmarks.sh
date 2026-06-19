#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT="test/benchmarks/.gas-snapshot"
OUTPUT="BENCHMARKS.md"
ETH_PRICE_USD="${ETH_PRICE_USD:-3000}"

forge snapshot --match-path 'test/benchmarks/*.t.sol' --snap "$SNAPSHOT"

tmp_output="$(mktemp)"
trap 'rm -f "$tmp_output"' EXIT

{
  cat <<'MARKDOWN'
# Namespace Issuance Gas Benchmarks

These benchmarks measure activation setup, end-to-end minting, renewal, and individual module function costs for the rule-based Namespace subname issuance architecture.

The minting benchmarks are end to end for the Namespace mint path: buyer calls `NamespaceController.mint`, configured rules evaluate eligibility and price effects, the payment module settles funds, the official ENSv2 `PermissionedRegistry` mints the label, and post-hooks run when configured.

Reference: [Foundry gas tracking](https://www.getfoundry.sh/forge/gas-tracking).

Run and regenerate this file:

```sh
./scripts/generate-benchmarks.sh
```

## Assumptions

MARKDOWN

  echo "- ETH price: \`\$$ETH_PRICE_USD\`"
  echo "- USD cost formula: \`gasUsed * gasPriceGwei * 1e-9 * ETH_PRICE_USD\`"
  echo "- \`Gwei used\` equals gas used denominated in gwei at a 1 gwei gas price."
  echo "- Reservation and whitelist set sizes are represented by Merkle proof depth. Activation stores one root, so activation gas is root-only."
  echo "- Resolver record benchmarks use \`BatchSetAddrToBuyerHook\` so one hook module can execute multiple resolver writes."
  echo "- Component estimates are benchmark deltas. They are useful for planning arbitrary combinations, but full end-to-end permutations remain the source of truth."
  echo "- Benchmark tables intentionally use four columns: name, scenario, gwei used, and USD at a 1 gwei gas price."
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

append_cost_model() {
  {
    echo "## Component Cost Model"
    echo
    echo "Use this section to estimate a custom configuration before adding a dedicated end-to-end benchmark. Start with the closest end-to-end baseline, add relevant deltas, then validate important production configurations with a real benchmark."
    echo
    echo "| Name | Scenario | Gwei used | USD @ 1 gwei |"
    echo "| --- | --- | ---: | ---: |"
  } >>"$tmp_output"

  awk -v eth="$ETH_PRICE_USD" '
    function gas_for(name) {
      return gas_by_name[name] + 0
    }
    function signed(value) {
      return sprintf("%+d", value)
    }
    function absolute(value) {
      return sprintf("%d", value)
    }
    function usd(gwei) {
      return gwei * 1e-9 * eth
    }
    function row(name, scenario, value) {
      printf "| %s | %s | %s | $%.6f |\n", name, scenario, value, usd(value + 0)
    }
    function delta(name, base) {
      return gas_for(name) - gas_for(base)
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
      row("No-rule mint baseline", "Absolute `mint_00_pncFreeNoRules`", absolute(gas_for("testBenchmark_mint_00_pncFreeNoRules")))
      row("One guard rule", "Delta: `mint_01` - `mint_00`", signed(delta("testBenchmark_mint_01_pncOneGuardRuleFree", "testBenchmark_mint_00_pncFreeNoRules")))
      row("One fixed-price ERC20 sale", "Delta: `mint_02` - `mint_00`", signed(delta("testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment", "testBenchmark_mint_00_pncFreeNoRules")))
      row("ERC20 split instead of direct payment", "Delta: `mint_03` - `mint_02`", signed(delta("testBenchmark_mint_03_pncOneFixedPriceRuleSplitPayment", "testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment")))
      row("Second free eligibility rule", "Delta: `mint_04` - `mint_01`", signed(delta("testBenchmark_mint_04_pncTwoRulesFreeNoResolver", "testBenchmark_mint_01_pncOneGuardRuleFree")))
      row("Three-rule paid stack", "Delta: `mint_08` - `mint_02`", signed(delta("testBenchmark_mint_08_pncThreeRulesERC20PaymentNoResolver", "testBenchmark_mint_02_pncOneFixedPriceRuleERC20Payment")))
      row("Recording post-hook", "Delta: `mint_10` - `mint_08`", signed(delta("testBenchmark_mint_10_pncThreeRulesERC20PaymentRecordingHook", "testBenchmark_mint_08_pncThreeRulesERC20PaymentNoResolver")))
      row("All-rule stack before resolver writes", "Delta: `mint_22` - `mint_09`", signed(delta("testBenchmark_mint_22_pncAllRulesSplitNoResolverWrites", "testBenchmark_mint_09_pncThreeRulesSplitPaymentNoResolver")))
      row("Batch resolver hook, three writes", "Delta: `mint_23` - `mint_22`", signed(delta("testBenchmark_mint_23_pncAllRulesSplitThreeResolverWrites", "testBenchmark_mint_22_pncAllRulesSplitNoResolverWrites")))
      row("Two additional resolver writes", "Delta: `mint_24` - `mint_23`", signed(delta("testBenchmark_mint_24_pncAllRulesSplitFiveResolverWrites", "testBenchmark_mint_23_pncAllRulesSplitThreeResolverWrites")))
      row("Extra resolver write", "Derived: (`mint_24` - `mint_23`) / 2", signed(int(delta("testBenchmark_mint_24_pncAllRulesSplitFiveResolverWrites", "testBenchmark_mint_23_pncAllRulesSplitThreeResolverWrites") / 2)))
      row("All-rule activation config", "Delta: `activation_24` - `activation_00`", signed(delta("testBenchmark_activation_24_pncAllRulesSplitFiveResolverWrites", "testBenchmark_activation_00_pncFreeNoRules")))
      row("PauseRule.evaluateMint", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_00_pause_evaluateMint")))
      row("SaleWindowRule.evaluateMint", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_01_saleWindow_evaluateMint")))
      row("LabelLengthRule.evaluateMint", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_02_labelLength_evaluateMint")))
      row("FixedPriceRule.evaluateMint, no overrides", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_03_fixedPriceNoLengthOverrides_evaluateMint")))
      row("FixedPriceRule.evaluateMint, 5 overrides", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_04_fixedPriceFiveLengthOverrides_evaluateMint")))
      row("FixedPriceRule.evaluateMint, 20 overrides", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_05_fixedPriceTwentyLengthOverrides_evaluateMint")))
      row("LengthPremiumRule.evaluateMint, 5 buckets", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_06_lengthPremiumFiveBuckets_evaluateMint")))
      row("LengthPremiumRule.evaluateMint, 20 buckets", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_07_lengthPremiumTwentyBuckets_evaluateMint")))
      row("TokenBalanceRule.evaluateMint", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_08_tokenBalanceDiscount_evaluateMint")))
      row("ReservationRule proof depth 4", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_09_reservation10_evaluateMint")))
      row("ReservationRule proof depth 10", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_10_reservation1000_evaluateMint")))
      row("Reservation proof sibling", "Derived per additional Merkle sibling", signed(int((gas_for("testBenchmark_profile_rule_10_reservation1000_evaluateMint") - gas_for("testBenchmark_profile_rule_09_reservation10_evaluateMint")) / 6)))
      row("WhitelistRule proof depth 4", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_11_whitelist10_evaluateMint")))
      row("WhitelistRule proof depth 10", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_12_whitelist1000_evaluateMint")))
      row("Whitelist proof sibling", "Derived per additional Merkle sibling", signed(int((gas_for("testBenchmark_profile_rule_12_whitelist1000_evaluateMint") - gas_for("testBenchmark_profile_rule_11_whitelist10_evaluateMint")) / 6)))
      row("LabelClassRule.evaluateMint", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_13_labelClassNumber_evaluateMint")))
      row("USDOracleRule.evaluateMint", "Absolute profile", absolute(gas_for("testBenchmark_profile_rule_14_usdOracle_evaluateMint")))
      row("ERC20Payment.collectMint", "Absolute profile", absolute(gas_for("testBenchmark_profile_payment_00_collectMintERC20")))
      row("ERC20SplitPayment.collectMint", "Absolute profile", absolute(gas_for("testBenchmark_profile_payment_01_collectMintSplitERC20")))
      row("Split payment premium", "Derived: `profile_payment_01` - `profile_payment_00`", signed(delta("testBenchmark_profile_payment_01_collectMintSplitERC20", "testBenchmark_profile_payment_00_collectMintERC20")))
      row("RecordingPostHook.afterMint", "Absolute profile", absolute(gas_for("testBenchmark_profile_hook_00_recordingPostHook_afterMint")))
      row("Batch resolver hook, three writes", "Absolute profile", absolute(gas_for("testBenchmark_profile_hook_01_batchResolverHookThreeWrites_afterMint")))
      row("Batch resolver hook, five writes", "Absolute profile", absolute(gas_for("testBenchmark_profile_hook_02_batchResolverHookFiveWrites_afterMint")))
    }
  ' "$SNAPSHOT" >>"$tmp_output"

  echo >>"$tmp_output"
}

append_table "Activation Benchmarks" \
  "testBenchmark_activation_" \
  "^testBenchmark_activation_[0-9]+_pnc"

append_table "Minting Benchmarks" \
  "testBenchmark_mint_" \
  "^testBenchmark_mint_[0-9]+_pnc"

append_table "Renewal Benchmarks" \
  "testBenchmark_renew_" \
  "^testBenchmark_renew_[0-9]+_"

append_table "Rule Function Profile" \
  "testBenchmark_profile_rule_" \
  "^testBenchmark_profile_rule_[0-9]+_"

append_table "Payment And Hook Function Profile" \
  "testBenchmark_profile_(payment|hook)_" \
  "^testBenchmark_profile_(payment|hook)_[0-9]+_"

append_cost_model

cat <<'MARKDOWN' >>"$tmp_output"
## Scenario Notes

- Activations call `NamespaceController.activate` with rule, payment, and hook configuration.
- Minting executes one `NamespaceController.mint` transaction after activation setup in `setUp()`.
- Renewal executes one `NamespaceController.renew` transaction against a label minted during setup.
- Rule profiles call each rule directly with realistic activation config so hotspots can be compared before optimizing internals.
- Reservation and whitelist proof scenarios use claim-based rules with Merkle proof depths represented by set size.
- Resolver record benchmarks use one batched post-hook module for multiple addr writes.
- Component estimates use benchmark deltas and direct module profiles so arbitrary combinations can be estimated before adding a dedicated benchmark.
MARKDOWN

mv "$tmp_output" "$OUTPUT"
