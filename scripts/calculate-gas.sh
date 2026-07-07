#!/usr/bin/env bash
set -euo pipefail

COMPONENTS="benchmarks/gas-components.tsv"
GAS_PRICE_GWEI="1"
ETH_PRICE_USD="${ETH_PRICE_USD:-3000}"
MODE="estimate"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/calculate-gas.sh list
  ./scripts/calculate-gas.sh [options] <component-key> [component-key...]

Options:
  --components-file <path>  Component TSV file. Default: benchmarks/gas-components.tsv
  --gas-price-gwei <value>  Gas price used for USD estimate. Default: 1
  --eth-price-usd <value>   ETH/USD price used for USD estimate. Default: $ETH_PRICE_USD or 3000
  -h, --help                Show this help.

Examples:
  ./scripts/calculate-gas.sh list
  ./scripts/calculate-gas.sh mint.free_no_rules delta.fixed_erc20_sale
  ./scripts/calculate-gas.sh --gas-price-gwei 5 mint.three_rules_erc20 hook.batch_resolver_3
EOF
}

keys=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    list)
      MODE="list"
      shift
      ;;
    --components-file)
      COMPONENTS="${2:?missing value for --components-file}"
      shift 2
      ;;
    --gas-price-gwei)
      GAS_PRICE_GWEI="${2:?missing value for --gas-price-gwei}"
      shift 2
      ;;
    --eth-price-usd)
      ETH_PRICE_USD="${2:?missing value for --eth-price-usd}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        keys+=("$1")
        shift
      done
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      keys+=("$1")
      shift
      ;;
  esac
done

if [ ! -f "$COMPONENTS" ]; then
  echo "Missing component catalog: $COMPONENTS" >&2
  echo "Run ./scripts/generate-benchmarks.sh first." >&2
  exit 1
fi

if [ "$MODE" = "list" ]; then
  awk -F '\t' '
    NR == 1 { next }
    {
      printf "%-48s %-8s %10d  %s\n", $1, $2, $3, $5
    }
  ' "$COMPONENTS"
  exit 0
fi

if [ "${#keys[@]}" -eq 0 ]; then
  usage >&2
  exit 2
fi

joined_keys="${keys[*]}"

awk -F '\t' \
  -v wanted="$joined_keys" \
  -v gas_price_gwei="$GAS_PRICE_GWEI" \
  -v eth_price_usd="$ETH_PRICE_USD" '
  BEGIN {
    requested_count = split(wanted, requested, " ")
  }
  NR == 1 { next }
  {
    gas[$1] = $3 + 0
    kind[$1] = $2
    description[$1] = $5
  }
  END {
    missing = 0
    for (i = 1; i <= requested_count; i++) {
      key = requested[i]
      if (!(key in gas)) {
        printf "Unknown component key: %s\n", key > "/dev/stderr"
        missing = 1
      }
    }
    if (missing) {
      print "Run ./scripts/calculate-gas.sh list to see available keys." > "/dev/stderr"
      exit 2
    }

    print "| Component | Kind | Gas | Description |"
    print "| --- | --- | ---: | --- |"

    total = 0
    profile_count = 0
    for (i = 1; i <= requested_count; i++) {
      key = requested[i]
      total += gas[key]
      if (kind[key] == "profile") {
        profile_count++
      }
      printf "| `%s` | %s | %d | %s |\n", key, kind[key], gas[key], description[key]
    }

    usd = total * gas_price_gwei * 1e-9 * eth_price_usd
    eth_cost = total * gas_price_gwei * 1e-9
    printf "\nTotal gas: %d\n", total
    printf "Estimated ETH @ %s gwei: %.9f ETH\n", gas_price_gwei, eth_cost
    printf "Estimated USD @ $%s/ETH: $%.6f\n", eth_price_usd, usd
    if (profile_count > 0) {
      print "\nNote: profile components are standalone module-call measurements. Prefer exact or delta components when one matches the full transaction shape."
    }
  }
' "$COMPONENTS"
