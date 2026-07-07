#!/usr/bin/env bash
set -euo pipefail

SNAPSHOT="test/benchmarks/.gas-snapshot"

forge snapshot --match-path 'test/benchmarks/*.t.sol' --snap "$SNAPSHOT"
python3 scripts/generate-benchmark-reports.py
