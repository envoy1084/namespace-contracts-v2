#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT="test/benchmarks/.gas-snapshot"
OUTPUT="BENCHMARKS.md"
ETH_PRICE_USD="${ETH_PRICE_USD:-3000}"

forge snapshot --match-path 'test/benchmarks/*.t.sol' --snap "$SNAPSHOT"

cat >"$OUTPUT" <<'MARKDOWN'
# Namespace Issuance Gas Benchmarks

These benchmarks isolate Namespace subname issuance paths. Activations and approvals are created in `setUp()`, then each benchmark test performs one `controller.mint(...)`.

Each benchmark is end to end for the Namespace mint path: buyer calls `NamespaceController.mint`, configured policies are checked, pricing modules are evaluated, ERC20 payment is collected, the processor and post-hooks run when configured, and the mint is executed against the official ENSv2 `PermissionedRegistry` implementation from `lib/contracts-v2`.

Reference: [Foundry gas tracking](https://www.getfoundry.sh/forge/gas-tracking).

Run and regenerate this file:

```sh
./scripts/generate-benchmarks.sh
```

Assumptions:

MARKDOWN

{
  echo "- ETH price: \`\$$ETH_PRICE_USD\`"
  echo "- USD cost formula: \`gasUsed * gasPriceGwei * 1e-9 * ETH_PRICE_USD\`"
  echo "- \`Gas consumed @ 1 gwei\` is the transaction fee in gwei at a 1 gwei gas price."
  echo
  echo "| Benchmark | Gas used | Gas consumed @ 1 gwei (gwei) | USD @ 0.1 gwei | USD @ 0.5 gwei | USD @ 1 gwei | USD @ 3 gwei | USD @ 5 gwei |"
  echo "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"
} >>"$OUTPUT"

awk -v eth="$ETH_PRICE_USD" '
  function usd(gas, gwei) {
    return gas * gwei * 1e-9 * eth
  }
  {
    name=$1
    sub(/NamespaceIssuanceGasBenchmarks:/, "", name)
    gas=$3
    gsub(/[()]/, "", gas)
    rows[name]=gas
  }
  END {
    order[1]="testBenchmark_freeMint_noPolicyNoPricing()"
    order[2]="testBenchmark_freeMint_onePolicy()"
    order[3]="testBenchmark_freeMint_threePolicies()"
    order[4]="testBenchmark_freeMint_fivePolicies()"
    order[5]="testBenchmark_erc20FixedPrice_noPolicy()"
    order[6]="testBenchmark_lengthPricing_twoPolicies()"
    order[7]="testBenchmark_erc20Split_threePolicies()"
    order[8]="testBenchmark_fullStack_fivePoliciesTwoPricingSplitHook()"

    for (i = 1; i <= 8; i++) {
      name=order[i]
      gas=rows[name]
      if (gas == "") {
        continue
      }
      printf "| `%s` | %d | %d | $%.6f | $%.6f | $%.6f | $%.6f | $%.6f |\n", \
        name, gas, gas, usd(gas, 0.1), usd(gas, 0.5), usd(gas, 1), usd(gas, 3), usd(gas, 5)
    }
  }
' "$SNAPSHOT" >>"$OUTPUT"

cat >>"$OUTPUT" <<'MARKDOWN'

## Scenario Notes

| Benchmark | Scenario |
| --- | --- |
| `testBenchmark_freeMint_noPolicyNoPricing()` | Free subname mint with no policies, no pricing modules, no split processor, and no hooks. |
| `testBenchmark_freeMint_onePolicy()` | Free mint with one sale-window policy. |
| `testBenchmark_freeMint_threePolicies()` | Free mint with sale-window, label-length, and ERC20 balance-gate policies. |
| `testBenchmark_freeMint_fivePolicies()` | Free mint with sale-window, label-length, ERC20 gate, reservation, and Merkle whitelist policies. |
| `testBenchmark_erc20FixedPrice_noPolicy()` | ERC20 fixed-price mint with no policies and direct treasury payment. |
| `testBenchmark_lengthPricing_twoPolicies()` | Mint with sale-window and label-length policies, fixed pricing plus length-based pricing, and direct treasury payment. |
| `testBenchmark_erc20Split_threePolicies()` | Mint with three policies, ERC20 fixed pricing, ERC20 payment collection, and split processor payout. |
| `testBenchmark_fullStack_fivePoliciesTwoPricingSplitHook()` | Mint with five policies, fixed plus length pricing, ERC20 split processing, and one post-mint hook. |
MARKDOWN
