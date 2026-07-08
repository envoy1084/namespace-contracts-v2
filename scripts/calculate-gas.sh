#!/usr/bin/env bash
set -euo pipefail

exec python3 scripts/calculate-gas.py "$@"
