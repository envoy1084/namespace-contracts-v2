#!/usr/bin/env python3
"""Interactive and scriptable gas calculator for Namespace benchmark components."""

from __future__ import annotations

import argparse
import csv
import os
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_COMPONENTS = Path("benchmarks/gas-components.tsv")
DEFAULT_GAS_PRICE_GWEI = 1.0
DEFAULT_ETH_PRICE_USD = float(os.environ.get("ETH_PRICE_USD", "3000"))


@dataclass(frozen=True)
class Component:
    key: str
    kind: str
    gas: int
    source: str
    description: str
    activation_gas: int | None

    @property
    def category(self) -> str:
        return self.key.split(".", 1)[0]


def read_components(path: Path) -> dict[str, Component]:
    if not path.exists():
        raise SystemExit(f"Missing component catalog: {path}\nRun ./scripts/generate-benchmarks.sh first.")

    components: dict[str, Component] = {}
    with path.open(newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            activation_raw = row["activationGas"]
            components[row["key"]] = Component(
                key=row["key"],
                kind=row["kind"],
                gas=int(row["gas"]),
                source=row["source"],
                description=row["description"],
                activation_gas=None if activation_raw == "n/a" else int(activation_raw),
            )
    return components


def eth_cost(gas: int, gas_price_gwei: float) -> float:
    return gas * gas_price_gwei * 1e-9


def usd_cost(gas: int, gas_price_gwei: float, eth_price_usd: float) -> float:
    return eth_cost(gas, gas_price_gwei) * eth_price_usd


def print_cost(label: str, gas: int, gas_price_gwei: float, eth_price_usd: float) -> None:
    print(f"\n{label}: {gas}")
    print(f"Estimated ETH @ {gas_price_gwei:g} gwei: {eth_cost(gas, gas_price_gwei):.9f} ETH")
    print(f"Estimated USD @ ${eth_price_usd:g}/ETH: ${usd_cost(gas, gas_price_gwei, eth_price_usd):.6f}")


def print_component_table(selected: list[Component], include_activation: bool) -> None:
    if include_activation:
        print("| Component | Kind | Runtime Gas | Activation Delta Gas | Description |")
        print("| --- | --- | ---: | ---: | --- |")
        for component in selected:
            activation = "n/a" if component.activation_gas is None else str(component.activation_gas)
            print(f"| `{component.key}` | {component.kind} | {component.gas} | {activation} | {component.description} |")
    else:
        print("| Component | Kind | Gas | Description |")
        print("| --- | --- | ---: | --- |")
        for component in selected:
            print(f"| `{component.key}` | {component.kind} | {component.gas} | {component.description} |")


def list_components(components: dict[str, Component]) -> None:
    for component in sorted(components.values(), key=lambda c: (c.category, c.kind, c.key)):
        activation = "" if component.activation_gas is None else f" activationDelta={component.activation_gas}"
        print(f"{component.key:<56} {component.kind:<8} {component.gas:>10}{activation}  {component.description}")


def selected_components(components: dict[str, Component], keys: list[str]) -> list[Component]:
    missing = [key for key in keys if key not in components]
    if missing:
        raise SystemExit(
            "Unknown component key(s): "
            + ", ".join(missing)
            + "\nRun ./scripts/calculate-gas.py list to see available keys."
        )
    return [components[key] for key in keys]


def estimate(
    components: dict[str, Component],
    keys: list[str],
    mode: str,
    gas_price_gwei: float,
    eth_price_usd: float,
) -> None:
    selected = selected_components(components, keys)
    print_component_table(selected, include_activation=mode in {"activation", "all"})

    runtime_total = sum(component.gas for component in selected)
    activation_delta = sum(component.activation_gas or 0 for component in selected)

    if mode in {"sum", "all"}:
        print_cost("Selected component gas", runtime_total, gas_price_gwei, eth_price_usd)
    if mode in {"activation", "all"}:
        base = components["activation.free_no_rules"].gas
        print_cost("Estimated activation gas", base + activation_delta, gas_price_gwei, eth_price_usd)
    if mode in {"mint", "all"}:
        base = components["mint.free_no_rules"].gas
        print_cost("Estimated mint gas", base + runtime_total, gas_price_gwei, eth_price_usd)
    if mode in {"renew", "all"}:
        base = components["renew.free_no_rules"].gas
        print_cost("Estimated renew gas", base + runtime_total, gas_price_gwei, eth_price_usd)

    if mode in {"activation", "all"} and any(component.activation_gas is None for component in selected):
        missing = [component.key for component in selected if component.activation_gas is None]
        print("\nNo activation delta is available for: " + ", ".join(f"`{key}`" for key in missing))


def parse_selection(raw: str, max_index: int) -> list[int]:
    selected: set[int] = set()
    for part in raw.replace(" ", "").split(","):
        if not part:
            continue
        if part == "all":
            return list(range(1, max_index + 1))
        if "-" in part:
            start_raw, end_raw = part.split("-", 1)
            start = int(start_raw)
            end = int(end_raw)
            selected.update(range(start, end + 1))
        else:
            selected.add(int(part))
    invalid = [index for index in selected if index < 1 or index > max_index]
    if invalid:
        raise ValueError(f"selection out of range: {invalid[0]}")
    return sorted(selected)


def interactive(components: dict[str, Component], gas_price_gwei: float, eth_price_usd: float) -> None:
    mode = prompt_choice("Estimate mode", ["activation", "mint", "renew", "sum", "all"], default="activation")
    gas_price_gwei = prompt_float("Gas price gwei", gas_price_gwei)
    eth_price_usd = prompt_float("ETH price USD", eth_price_usd)

    candidates = interactive_candidates(components, mode)
    for index, component in enumerate(candidates, start=1):
        activation = "" if component.activation_gas is None else f", activation +{component.activation_gas}"
        print(f"{index:>2}. {component.key} [{component.kind}, {component.gas} gas{activation}]")
        print(f"    {component.description}")

    while True:
        raw = input("\nSelect components by number, range, comma list, or 'all': ").strip()
        try:
            indexes = parse_selection(raw, len(candidates))
            break
        except (ValueError, IndexError) as exc:
            print(f"Invalid selection: {exc}")

    keys = [candidates[index - 1].key for index in indexes]
    print()
    estimate(components, keys, mode, gas_price_gwei, eth_price_usd)


def interactive_candidates(components: dict[str, Component], mode: str) -> list[Component]:
    values = list(components.values())
    if mode == "activation":
        values = [
            component
            for component in values
            if component.kind == "profile"
            and component.activation_gas is not None
            and component.category in {"rule", "payment", "hook"}
        ]
    elif mode == "mint":
        values = [component for component in values if component.category in {"rule", "payment", "hook"}]
    elif mode == "renew":
        values = [component for component in values if component.category in {"rule_renew", "payment_renew", "hook_renew"}]
    elif mode == "sum":
        values = [component for component in values if component.kind in {"exact", "floor", "delta", "slice"}]
    else:
        values = [component for component in values if component.kind == "profile"]
    return sorted(values, key=lambda c: (c.category, c.key))


def prompt_choice(label: str, choices: list[str], default: str) -> str:
    rendered = "/".join(choice.upper() if choice == default else choice for choice in choices)
    while True:
        value = input(f"{label} ({rendered}): ").strip().lower()
        if not value:
            return default
        if value in choices:
            return value
        print("Choose one of: " + ", ".join(choices))


def prompt_float(label: str, default: float) -> float:
    while True:
        value = input(f"{label} [{default:g}]: ").strip()
        if not value:
            return default
        try:
            return float(value)
        except ValueError:
            print("Enter a numeric value.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--components-file", type=Path, default=DEFAULT_COMPONENTS)
    parser.add_argument("--gas-price-gwei", type=float, default=DEFAULT_GAS_PRICE_GWEI)
    parser.add_argument("--eth-price-usd", type=float, default=DEFAULT_ETH_PRICE_USD)

    subparsers = parser.add_subparsers(dest="command")
    subparsers.add_parser("list", help="List available component keys.")
    subparsers.add_parser("interactive", help="Select components interactively.")

    estimate_parser = subparsers.add_parser("estimate", help="Estimate activation, mint, renew, or all totals.")
    estimate_parser.add_argument("keys", nargs="+")
    estimate_parser.add_argument("--mode", choices=["activation", "mint", "renew", "sum", "all"], default="all")

    sum_parser = subparsers.add_parser("sum", help="Sum selected component gas directly.")
    sum_parser.add_argument("keys", nargs="+")
    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    components = read_components(args.components_file)

    command = args.command or "interactive"
    if command == "list":
        list_components(components)
    elif command == "interactive":
        interactive(components, args.gas_price_gwei, args.eth_price_usd)
    elif command == "estimate":
        estimate(components, args.keys, args.mode, args.gas_price_gwei, args.eth_price_usd)
    elif command == "sum":
        estimate(components, args.keys, "sum", args.gas_price_gwei, args.eth_price_usd)
    else:
        parser.error(f"unknown command: {command}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
