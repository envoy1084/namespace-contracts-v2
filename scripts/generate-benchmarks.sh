#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT="benchmarks/.gas-snapshot"
MATCH_CONTRACT='Namespace(ActivationGasBenchmarks|MintGasBenchmarks|ActivationProfileGasBenchmarks|RuleProfileGasBenchmarks|PaymentHookGasBenchmarks|RegistryGasBenchmarks|ActivationSliceProfile|RuntimeSliceProfile)'
SNAPSHOT_TMP="$(mktemp)"
SLICE_LOG="$(mktemp)"
trap 'rm -f "$SNAPSHOT_TMP" "$SLICE_LOG"' EXIT

forge clean
forge snapshot --match-contract "$MATCH_CONTRACT" --snap "$SNAPSHOT_TMP"
if ! grep -q 'testBenchmark_activation_00_pncFreeNoRules' "$SNAPSHOT_TMP"; then
    echo "benchmark snapshot did not include expected Namespace benchmark tests" >&2
    exit 1
fi
mv "$SNAPSHOT_TMP" "$SNAPSHOT"
forge test --match-contract 'Namespace(Activation|Runtime)SliceProfile' -vv > "$SLICE_LOG"
python3 scripts/generate-benchmark-reports.py --slice-log "$SLICE_LOG"
