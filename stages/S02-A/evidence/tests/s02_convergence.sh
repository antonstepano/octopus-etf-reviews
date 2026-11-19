#!/usr/bin/env bash
# S02-A: numerical convergence study on the UNMODIFIED baseline binary.
#
# Purpose: derive the numerical floor for total energy / eigenvalues of a
# single C atom (NC pseudo-dojo PBE) as a function of grid spacing and
# simulation-box radius. The resulting numbers are the only admissible
# source of tolerances for the S02 test ladder (review Q6).
#
# This script does NOT test physics. It measures discretisation error of
# the baseline code so that later ETF tests can distinguish a real signal
# from grid noise.
#
# Usage:  bash tests/s02_convergence.sh
# Output: results/s02_convergence/<case>/  and reports/s02_convergence.csv
# Exit:   0 only if every case ran and produced a parseable total energy.

set -u
set -o pipefail
export LC_ALL=C   # decimal point, not comma (ru_RU locale breaks CSV)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OCT="$ROOT/build/baseline-cmake/octopus"
SHARE="$ROOT/build/baseline-cmake/share"
PP="$ROOT/octopus-baseline/share/pseudopotentials/pseudo-dojo.org/nc-sr-05_pbe_standard/C.upf"
OUT="$ROOT/results/s02_convergence"
CSV="$ROOT/reports/s02_convergence.csv"

for f in "$OCT" "$PP"; do
  if [ ! -e "$f" ]; then echo "FATAL: missing $f" >&2; exit 2; fi
done
if [ ! -d "$SHARE" ]; then echo "FATAL: missing OCTOPUS_SHARE $SHARE" >&2; exit 2; fi

mkdir -p "$OUT" "$(dirname "$CSV")"
printf 'case,spacing_bohr,radius_bohr,exit_code,total_energy_H,eigen_1_H,eigen_2_H,walltime_s,log\n' > "$CSV"

run_case() {
  local name="$1" spacing="$2" radius="$3"
  local dir="$OUT/$name"
  rm -rf "$dir"; mkdir -p "$dir"
  cp "$PP" "$dir/C.upf"

  cat > "$dir/inp" <<EOF
CalculationMode = gs
Dimensions = 3
PeriodicDimensions = 0
BoxShape = sphere
Radius = $radius
Spacing = $spacing

%Species
  "C" | species_pseudo | file | "C.upf"
%

%Coordinates
  "C" | 0 | 0 | 0
%

ExtraStates = 2
EOF

  local t0 t1 wall rc
  t0=$(date +%s.%N)
  ( cd "$dir" && OCTOPUS_SHARE="$SHARE" "$OCT" > run.log 2>&1 )
  rc=$?
  t1=$(date +%s.%N)
  wall=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}')

  local etot e1 e2
  etot=""; e1=""; e2=""
  if [ -f "$dir/static/info" ]; then
    etot=$(awk '/^ *Total *=/{print $3; exit}' "$dir/static/info")
    # first two eigenvalues listed under "Eigenvalues [H]"
    # rows look like: "   1   --    -0.493426       2.000000"  -> eigenvalue is field 3
    e1=$(awk '/Eigenvalues \[H\]/{f=1;next} f&&/^ *[0-9]+ +--/{print $3; exit}' "$dir/static/info")
    e2=$(awk '/Eigenvalues \[H\]/{f=1;next} f&&/^ *[0-9]+ +--/{c++; if(c==2){print $3; exit}}' "$dir/static/info")
  fi

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$name" "$spacing" "$radius" "$rc" "${etot:-NA}" "${e1:-NA}" "${e2:-NA}" "$wall" \
    "results/s02_convergence/$name/run.log" >> "$CSV"

  printf '  %-14s spacing=%-5s R=%-4s exit=%s Etot=%s wall=%ss\n' \
    "$name" "$spacing" "$radius" "$rc" "${etot:-NA}" "$wall"
  return $rc
}

echo "== S02-A convergence study (baseline binary, unmodified) =="
echo "binary: $OCT"
echo "pseudo: $PP"
echo

fail=0
# Series 1: spacing convergence at fixed box R = 6.0 bohr
for s in 0.50 0.45 0.40 0.35 0.30; do
  run_case "sp${s}_R6.0" "$s" 6.0 || fail=1
done
# Series 2: box convergence at fixed spacing 0.35 bohr
for r in 5.0 7.0 8.0; do
  run_case "sp0.35_R${r}" 0.35 "$r" || fail=1
done
# Series 3: spacing convergence at the large box R = 8.0 bohr.
# Needed because at R = 6.0 the box-truncation error (~5 mHa) is larger than
# the spacing differences at fine meshes, so series 1 alone cannot separate
# the two error sources.
for s in 0.50 0.45 0.40 0.30; do
  run_case "sp${s}_R8.0" "$s" 8.0 || fail=1
done

echo
echo "CSV: $CSV"
if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAILED (at least one case returned non-zero)" >&2
  exit 1
fi
if grep -q ',NA,' "$CSV"; then
  echo "RESULT: FAILED (unparseable energy in CSV)" >&2
  exit 1
fi
echo "RESULT: PASSED (all cases ran, all energies parsed)"
exit 0
