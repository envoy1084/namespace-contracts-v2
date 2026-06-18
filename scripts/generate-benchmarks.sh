#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT="test/benchmarks/.gas-snapshot"
BASELINE_SNAPSHOT="benchmarks/baselines/policy-pricing-architecture.gas-snapshot"
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
  echo "- \`Gas consumed @ 1 gwei\` is the transaction fee in gwei at a 1 gwei gas price."
  echo "- Reservation and whitelist set sizes are represented by Merkle proof depth. Activation stores one root, so activation gas is root-only."
  echo "- Resolver record benchmarks use \`BatchSetAddrToBuyerHook\` so one hook module can execute multiple resolver writes."
  echo "- The legacy baseline lives at \`$BASELINE_SNAPSHOT\` and represents the previous policy/pricing/processor architecture."
  echo
} >"$tmp_output"

append_table() {
  local title="$1"
  local pattern="$2"
  local strip_pattern="$3"

  {
    echo "## $title"
    echo
    echo "| Benchmark | Scenario | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |"
    echo "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"
  } >>"$tmp_output"

  awk -v eth="$ETH_PRICE_USD" -v pattern="$pattern" -v strip="$strip_pattern" '
    function usd(gas, gwei) {
      return gas * gwei * 1e-9 * eth
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
      sub(/^NamespaceIssuanceGasBenchmarks:/, "", name)
      gas=$3
      gsub(/[()]/, "", gas)
      printf "| `%s` | %s | %d | %d | $%.6f | $%.6f | $%.6f | $%.6f | $%.6f |\n", \
        name, humanize(name), gas, gas, usd(gas, 0.1), usd(gas, 0.5), usd(gas, 1), usd(gas, 3), usd(gas, 5)
    }
  ' "$SNAPSHOT" >>"$tmp_output"

  echo >>"$tmp_output"
}

append_comparison() {
  if [[ ! -f "$BASELINE_SNAPSHOT" ]]; then
    return
  fi

  {
    echo "## Baseline Comparison"
    echo
    echo "| Scenario | Legacy benchmark | Legacy gas | Rule benchmark | Rule gas | Delta | Delta % |"
    echo "| --- | --- | ---: | --- | ---: | ---: | ---: |"
  } >>"$tmp_output"

  awk -v baseline="$BASELINE_SNAPSHOT" -v snapshot="$SNAPSHOT" '
    function gas_for(file, key, line, gas) {
      while ((getline line < file) > 0) {
        if (line ~ key) {
          gas = line
          sub(/^.*\(gas: /, "", gas)
          sub(/\).*$/, "", gas)
          close(file)
          return gas + 0
        }
      }
      close(file)
      return -1
    }
    function row(label, legacy_key, rule_key, legacy_name, rule_name, legacy_gas, rule_gas, delta, pct) {
      legacy_gas = gas_for(baseline, legacy_key)
      rule_gas = gas_for(snapshot, rule_key)
      if (legacy_gas < 0 || rule_gas < 0) {
        return
      }
      delta = rule_gas - legacy_gas
      pct = legacy_gas == 0 ? 0 : (delta * 100 / legacy_gas)
      printf "| %s | `%s` | %d | `%s` | %d | %+d | %+.2f%% |\n", label, legacy_name, legacy_gas, rule_name, rule_gas, delta, pct
    }
    BEGIN {
      row("Full-stack activation", "testBenchmark_activation_13_compositePolicyCompositePricingDirectSplitFiveResolverWrites", "testBenchmark_activation_02_fullStackSevenRulesSplitPaymentFiveResolverWrites", "activation_13_compositePolicyCompositePricingDirectSplitFiveResolverWrites", "activation_02_fullStackSevenRulesSplitPaymentFiveResolverWrites")
      row("Full-stack mint", "testBenchmark_mint_18_fullStackCompositePolicyCompositePricingDirectSplitFiveResolverWrites", "testBenchmark_mint_02_fullStackRulesSplitPaymentFiveResolverWrites", "mint_18_fullStackCompositePolicyCompositePricingDirectSplitFiveResolverWrites", "mint_02_fullStackRulesSplitPaymentFiveResolverWrites")
    }
  ' >>"$tmp_output"

  echo >>"$tmp_output"
}

append_table "Activation Benchmarks" \
  "^NamespaceIssuanceGasBenchmarks:testBenchmark_activation_" \
  "^testBenchmark_activation_[0-9]+_"

append_table "Minting Benchmarks" \
  "^NamespaceIssuanceGasBenchmarks:testBenchmark_mint_" \
  "^testBenchmark_mint_[0-9]+_"

append_table "Renewal Benchmarks" \
  "^NamespaceIssuanceGasBenchmarks:testBenchmark_renew_" \
  "^testBenchmark_renew_[0-9]+_"

append_table "Rule Function Profile" \
  "^NamespaceIssuanceGasBenchmarks:testBenchmark_profile_rule_" \
  "^testBenchmark_profile_rule_[0-9]+_"

append_table "Payment And Hook Function Profile" \
  "^NamespaceIssuanceGasBenchmarks:testBenchmark_profile_(payment|hook)_" \
  "^testBenchmark_profile_(payment|hook)_[0-9]+_"

append_comparison

cat <<'MARKDOWN' >>"$tmp_output"
## Scenario Notes

| Area | Notes |
| --- | --- |
| Activations | Activation benchmarks call `NamespaceController.activate` with rule, payment, and hook configuration. |
| Minting | Minting benchmarks execute one `NamespaceController.mint` transaction after activation setup in `setUp()`. |
| Renewal | Renewal benchmarks execute one `NamespaceController.renew` transaction against a label minted during setup. |
| Rules | Rule profiles call each rule directly with realistic activation config so hotspots can be compared before optimizing internals. |
| Reservations | Reservation proof scenarios use the claim-based `ReservationRule`, which can block, buyer-bind, and override prices. |
| Whitelists | Whitelist proof scenarios use `WhitelistRule` claims, which can allow, block, discount, or add/override prices. |
| Resolver hooks | Resolver record benchmarks use one batched post-hook module for multiple addr writes. |
| Full stack | The full-stack benchmark uses seven rules, `ERC20SplitPaymentModule`, the official ENSv2 registry, and `BatchSetAddrToBuyerHook`. |
MARKDOWN

mv "$tmp_output" "$OUTPUT"
