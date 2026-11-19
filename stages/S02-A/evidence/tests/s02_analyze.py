#!/usr/bin/env python3
"""S02-A analysis: turn reports/s02_convergence.csv into the numerical floor.

Reads only the CSV produced by tests/s02_convergence.sh (no hidden data).
Prints a table of successive differences and the derived tolerance proposal.

Usage: python3 tests/s02_analyze.py
"""
import csv
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV = os.path.join(ROOT, "reports", "s02_convergence.csv")


def load():
    rows = []
    with open(CSV, newline="") as fh:
        for r in csv.DictReader(fh):
            rows.append(
                {
                    "case": r["case"],
                    "h": float(r["spacing_bohr"]),
                    "R": float(r["radius_bohr"]),
                    "rc": int(r["exit_code"]),
                    "E": float(r["total_energy_H"]),
                    "e1": float(r["eigen_1_H"]),
                    "e2": float(r["eigen_2_H"]),
                }
            )
    return rows


def series(rows, key, fixed_key, fixed_val):
    sel = [r for r in rows if abs(r[fixed_key] - fixed_val) < 1e-9]
    return sorted(sel, key=lambda r: r[key])


def report(title, sel, key, unit):
    print(f"\n{title}")
    print(f"  {key:>8} {unit:>6}   {'E_total [Ha]':>14} {'dE vs prev [mHa]':>17}")
    prev = None
    for r in sel:
        d = "" if prev is None else f"{1e3 * (r['E'] - prev):+9.3f}"
        print(f"  {r[key]:8.3f} {unit:>6}   {r['E']:14.8f} {d:>17}")
        prev = r["E"]
    spread = 1e3 * (max(x["E"] for x in sel) - min(x["E"] for x in sel))
    print(f"  spread over this series: {spread:.3f} mHa")
    return spread


def main():
    rows = load()
    bad = [r for r in rows if r["rc"] != 0]
    if bad:
        print(f"FAILED: {len(bad)} case(s) with non-zero exit code", file=sys.stderr)
        return 1

    print(f"cases: {len(rows)}  (all exit_code = 0)")

    s1 = report("Series 1 — spacing at fixed R = 6.0 bohr", series(rows, "h", "R", 6.0), "h", "bohr")
    s2 = report("Series 2 — box radius at fixed spacing 0.35 bohr", series(rows, "R", "h", 0.35), "R", "bohr")
    s3 = report("Series 3 — spacing at fixed R = 8.0 bohr", series(rows, "h", "R", 8.0), "h", "bohr")

    # Box extrapolation from series 2 (R = 5,6,7,8 at h = 0.35)
    b = series(rows, "R", "h", 0.35)
    d56 = b[1]["E"] - b[0]["E"]
    d67 = b[2]["E"] - b[1]["E"]
    d78 = b[3]["E"] - b[2]["E"]
    print("\nBox convergence (h = 0.35):")
    print(f"  E(R=5) -> E(R=6): {1e3*d56:+.3f} mHa")
    print(f"  E(R=6) -> E(R=7): {1e3*d67:+.3f} mHa")
    print(f"  E(R=7) -> E(R=8): {1e3*d78:+.3f} mHa")
    print(f"  ratio d67/d78 = {d67/d78:.2f}  (geometric tail -> residual at R=8 ~ {1e3*d78*d78/d67:.3f} mHa)")

    print("\nEigenvalue (state 1, 2s) at R = 8.0:")
    for r in series(rows, "h", "R", 8.0):
        print(f"  h={r['h']:.2f}  e1={r['e1']:.6f}  e2={r['e2']:.6f}")

    print("\n--- Derived numerical floor (C atom, NC pseudo-dojo PBE) ---")
    print(f"  spacing-induced spread at R=8: {s3:.3f} mHa")
    print(f"  box-induced spread at h=0.35 : {s2:.3f} mHa")
    print("  => total-energy differences below ~5 mHa are NOT resolvable")
    print("     on this mesh family; a 1 mHa claim requires h <= 0.30 AND R >= 8")
    print("     with an explicit extrapolation, and even then is UNVERIFIED.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
