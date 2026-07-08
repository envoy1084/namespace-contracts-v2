# Namespace Gas Benchmarks

Benchmark output is split into focused reports:

1. [Profile Gas Benchmarks](./PROFILE_BENCHMARKS.md) - rule, payment, hook, and logical controller slice gas models.
2. [Scenario Gas Benchmarks](./SCENARIO_BENCHMARKS.md) - low/high activation, mint, renewal, and direct registry baselines.

Regenerate all benchmark artifacts:

```sh
./scripts/generate-benchmarks.sh
```

Interactive gas calculator:

```sh
./scripts/calculate-gas.py interactive
```
