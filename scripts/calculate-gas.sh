#!/usr/bin/env bash
set -euo pipefail

COMPONENTS="benchmarks/gas-components.tsv"
GAS_PRICE_GWEI="1"
ETH_PRICE_USD="${ETH_PRICE_USD:-3000}"
MODE="sum"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/calculate-gas.sh list
  ./scripts/calculate-gas.sh estimate <profile-component-key> [profile-component-key...]
  ./scripts/calculate-gas.sh [options] <component-key> [component-key...]

Options:
  --components-file <path>  Component TSV file. Default: benchmarks/gas-components.tsv
  --gas-price-gwei <value>  Gas price used for USD estimate. Default: 1
  --eth-price-usd <value>   ETH/USD price used for USD estimate. Default: $ETH_PRICE_USD or 3000
  -h, --help                Show this help.

Examples:
  ./scripts/calculate-gas.sh list
  ./scripts/calculate-gas.sh estimate rule.sale_window_bounded rule.label_length rule.fixed_price_no_overrides payment.erc20
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
    estimate|profile-estimate)
      MODE="profile_estimate"
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
    activation_gas[$1] = $6
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

    if ("'"$MODE"'" == "profile_estimate") {
      print "| Component | Kind | Runtime Gas | Activation Delta Gas | Description |"
      print "| --- | --- | ---: | ---: | --- |"

      runtime_total = 0
      activation_delta_total = 0
      missing_activation_count = 0
      non_profile_count = 0
      for (i = 1; i <= requested_count; i++) {
        key = requested[i]
        runtime_total += gas[key]
        activation = activation_gas[key]
        if (activation == "" || activation == "n/a") {
          activation_display = "n/a"
          missing_activation[++missing_activation_count] = key
        } else {
          activation_display = activation
          activation_delta_total += activation + 0
        }
        if (kind[key] != "profile") {
          non_profile[++non_profile_count] = key
        }
        printf "| `%s` | %s | %d | %s | %s |\n", key, kind[key], gas[key], activation_display, description[key]
      }

      mint_estimate = gas["mint.free_no_rules"] + runtime_total
      activation_estimate = gas["activation.free_no_rules"] + activation_delta_total

      print_cost("Runtime profile total", runtime_total)
      print_cost("Estimated mint gas", mint_estimate)
      print_cost("Estimated activation gas", activation_estimate)

      print "\nNotes:"
      print "- Mint estimate = `mint.free_no_rules` + selected runtime profile gas."
      print "- Activation estimate = `activation.free_no_rules` + selected activation profile deltas where available."
      print "- Profile estimates are planning aids. Prefer exact scenario components when one matches the full transaction shape."
      if (missing_activation_count > 0) {
        printf "- No activation delta is available for:"
        for (i = 1; i <= missing_activation_count; i++) printf " `%s`", missing_activation[i]
        print "."
      }
      if (non_profile_count > 0) {
        printf "- Non-profile keys were included as runtime gas only:"
        for (i = 1; i <= non_profile_count; i++) printf " `%s`", non_profile[i]
        print "."
      }
      exit
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

    print_cost("Total gas", total)
    if (profile_count > 0) {
      print "\nNote: profile components are standalone module-call measurements. Prefer exact or delta components when one matches the full transaction shape."
    }
  }
  function print_cost(label, total, usd, eth_cost) {
    usd = total * gas_price_gwei * 1e-9 * eth_price_usd
    eth_cost = total * gas_price_gwei * 1e-9
    printf "\n%s: %d\n", label, total
    printf "Estimated ETH @ %s gwei: %.9f ETH\n", gas_price_gwei, eth_cost
    printf "Estimated USD @ $%s/ETH: $%.6f\n", eth_price_usd, usd
  }
' "$COMPONENTS"
