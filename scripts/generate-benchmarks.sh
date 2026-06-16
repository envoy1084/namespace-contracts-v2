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

These benchmarks measure activation setup, end-to-end minting, and individual module functions for Namespace subname issuance.

The minting benchmarks are end to end for the Namespace mint path: buyer calls `NamespaceController.mint`, configured policies are checked, pricing modules are evaluated, ERC20 payment is collected, the processor and post-hooks run when configured, and the mint is executed against the official ENSv2 `PermissionedRegistry` implementation from `lib/contracts-v2`.

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
  echo "- Reservation and whitelist set sizes are represented by Merkle proof depth. Activation stores one root, so activation gas is intentionally flat across 10, 100, 200, or 1000-entry sets."
  echo '- Resolver record benchmarks use repeated `SetAddrToBuyerHook` addr writes because the current hook surface benchmarks resolver post-hook count, not distinct resolver record types.'
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

append_table "Activation Benchmarks" \
  "^NamespaceIssuanceGasBenchmarks:testBenchmark_activation_" \
  "^testBenchmark_activation_[0-9]+_"

append_table "Minting Benchmarks" \
  "^NamespaceIssuanceGasBenchmarks:testBenchmark_mint_" \
  "^testBenchmark_mint_[0-9]+_"

append_table "Policy Function Profile" \
  "^NamespaceIssuanceGasBenchmarks:testBenchmark_profile_policy_" \
  "^testBenchmark_profile_policy_[0-9]+_"

append_table "Pricing Function Profile" \
  "^NamespaceIssuanceGasBenchmarks:testBenchmark_profile_pricing_" \
  "^testBenchmark_profile_pricing_[0-9]+_"

append_table "Payment, Processor, And Hook Function Profile" \
  "^NamespaceIssuanceGasBenchmarks:testBenchmark_profile_(payment|processor|hook)_" \
  "^testBenchmark_profile_(payment|processor|hook)_[0-9]+_"

cat <<'MARKDOWN' >>"$tmp_output"
## Scenario Notes

| Area | Notes |
| --- | --- |
| Activations | Activation benchmarks call `NamespaceController.activate` with the named policy, pricing, processor, and hook configuration. |
| Minting | Minting benchmarks execute one `NamespaceController.mint` transaction after activation setup in `setUp()`. |
| Reservations | Reservation proof scenarios use proofs for the named set size. Larger sets increase proof depth and mint gas, while activation gas remains root-only. |
| Whitelists | Whitelist scenarios use `ACCOUNT_LABEL` leaves so both buyer and requested label are proven. |
| Resolver hooks | 1, 3, and 5 record scenarios benchmark 1, 3, and 5 post-mint resolver addr hook calls. |
| Full stack | The full-stack benchmark combines sale window, label length, ERC20 gate, reservation, whitelist, class pricing, fixed pricing, length pricing, ERC20 payment, split processing, and five resolver hooks. |
| Function profiles | Profile rows call individual module functions directly with realistic activation config so hotspots can be compared before optimizing internals. |
MARKDOWN

mv "$tmp_output" "$OUTPUT"
