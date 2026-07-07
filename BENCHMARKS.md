# Namespace Gas Benchmarks

Benchmark output is split into focused reports:

1. [Profile Gas Benchmarks](./PROFILE_BENCHMARKS.md) - direct rule, payment, and hook profile calls plus machine-readable profile JSON.
2. [Scenario Gas Benchmarks](./SCENARIO_BENCHMARKS.md) - activation, mint, renewal, direct registry, exact scenario, and delta benchmarks.

Regenerate all benchmark artifacts:

```sh
./scripts/generate-benchmarks.sh
```

Calculator inputs:

- [`benchmarks/gas-components.tsv`](./benchmarks/gas-components.tsv)
- [`benchmarks/profile-gas-report.json`](./benchmarks/profile-gas-report.json)
