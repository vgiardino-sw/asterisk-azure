#!/usr/bin/env python3
"""Collapse Meta CIDR routes into Terraform-ready meta_source_ips."""

from __future__ import annotations

import argparse
from ipaddress import ip_network, collapse_addresses
from pathlib import Path


def read_networks(path: Path):
    networks = []
    skipped = 0
    for i, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line:
            continue
        try:
            networks.append(ip_network(line, strict=False))
        except ValueError:
            skipped += 1
            print(f"[warn] skipped invalid CIDR at line {i}: {line}")
    return networks, skipped


def render_hcl(networks):
    body = "\n".join(f'  "{net}",' for net in networks)
    return f"meta_source_ips = [\n{body}\n]\n"


def main():
    parser = argparse.ArgumentParser(description="Collapse CIDRs for Terraform meta_source_ips")
    parser.add_argument("input", type=Path, help="Path to text file with one CIDR per line")
    parser.add_argument("-o", "--output", type=Path, help="Optional output file path")
    args = parser.parse_args()

    networks, skipped = read_networks(args.input)
    if not networks:
        raise SystemExit("No valid CIDRs found in input file.")

    collapsed = list(collapse_addresses(sorted(set(networks), key=lambda n: (n.version, int(n.network_address), n.prefixlen))))
    rendered = render_hcl(collapsed)

    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")

    print(f"\n# stats: original={len(networks)} unique={len(set(networks))} collapsed={len(collapsed)} skipped={skipped}")


if __name__ == "__main__":
    main()
