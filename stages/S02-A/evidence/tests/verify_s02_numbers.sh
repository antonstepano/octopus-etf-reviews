#!/usr/bin/env bash
# Verify that every quantitative claim in reports/s02_convergence.md is
# reproducible from reports/s02_convergence.csv.
#
# This is the S02 analogue of tests/verify_s01_refs.sh: it does not judge the
# physics, it only refuses to let the report and the data drift apart.
#
# Usage: bash tests/verify_s02_numbers.sh
# Exit:  0 = all checks pass, 1 = at least one mismatch.

set -u
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSV="$ROOT/reports/s02_convergence.csv"
MD="$ROOT/reports/s02_convergence.md"

[ -f "$CSV" ] || { echo "FATAL: missing $CSV" >&2; exit 2; }
[ -f "$MD" ]  || { echo "FATAL: missing $MD"  >&2; exit 2; }

pass=0; fail=0
check() { # name expected actual
  if [ "$2" = "$3" ]; then
    printf '  OK   %-46s %s\n' "$1" "$3"; pass=$((pass+1))
  else
    printf '  FAIL %-46s expected=%s actual=%s\n' "$1" "$2" "$3"; fail=$((fail+1))
  fi
}

E() { awk -F, -v c="$1" '$1==c{print $5}' "$CSV"; }

echo "== S02-A numeric verification =="

# --- raw energies quoted in the report tables ---
check "E(sp0.30_R8.0)"  "-5.68555889" "$(E sp0.30_R8.0)"
check "E(sp0.35_R8.0)"  "-5.68899020" "$(E sp0.35_R8.0)"
check "E(sp0.40_R8.0)"  "-5.68716817" "$(E sp0.40_R8.0)"
check "E(sp0.45_R8.0)"  "-5.66790933" "$(E sp0.45_R8.0)"
check "E(sp0.50_R8.0)"  "-5.63531966" "$(E sp0.50_R8.0)"
check "E(sp0.35_R5.0)"  "-5.66967754" "$(E sp0.35_R5.0)"
check "E(sp0.35_R6.0)"  "-5.68425426" "$(E sp0.35_R6.0)"
check "E(sp0.35_R7.0)"  "-5.68797201" "$(E sp0.35_R7.0)"

# --- derived quantities quoted in section 4 ---
spread3=$(awk -F, 'NR>1 && $3=="8.0"{if(min==""||$5<min)min=$5; if(max==""||$5>max)max=$5} END{printf "%.3f", 1000*(max-min)}' "$CSV")
check "spread, series 3 (mHa)" "53.671" "$spread3"

fine=$(awk -F, 'NR>1 && $3=="8.0" && ($2=="0.30"||$2=="0.35"||$2=="0.40"){if(min==""||$5<min)min=$5; if(max==""||$5>max)max=$5} END{printf "%.3f", 1000*(max-min)}' "$CSV")
check "fine-mesh spread h=0.30..0.40 (mHa)" "3.431" "$fine"

spread2=$(awk -F, 'NR>1 && $2=="0.35"{if(min==""||$5<min)min=$5; if(max==""||$5>max)max=$5} END{printf "%.3f", 1000*(max-min)}' "$CSV")
check "spread, series 2 R=5..8 (mHa)" "19.313" "$spread2"

ratio=$(awk -F, 'NR>1 && $2=="0.35"{e[$3]=$5} END{d67=e["7.0"]-e["6.0"]; d78=e["8.0"]-e["7.0"]; printf "%.2f", d67/d78}' "$CSV")
check "box tail ratio d67/d78" "3.65" "$ratio"

resid=$(awk -F, 'NR>1 && $2=="0.35"{e[$3]=$5} END{d67=e["7.0"]-e["6.0"]; d78=e["8.0"]-e["7.0"]; r=1000*d78*d78/d67; if(r<0)r=-r; printf "%.2f", r}' "$CSV")
check "extrapolated box residual at R=8 (mHa)" "0.28" "$resid"

# --- every case must have exit_code 0 ---
nz=$(awk -F, 'NR>1 && $4!=0' "$CSV" | wc -l)
check "cases with non-zero exit code" "0" "$nz"

# --- the report must actually contain these numbers ---
for tok in "53.7 mHa" "3.4 mHa" "19.3 mHa" "0.28 mHa" "3.65" "-5.68899020" "-5.68555889"; do
  if grep -qF -- "$tok" "$MD"; then
    printf '  OK   report contains %-34s\n' "\"$tok\""; pass=$((pass+1))
  else
    printf '  FAIL report missing %-35s\n' "\"$tok\""; fail=$((fail+1))
  fi
done

echo
echo "checks passed: $pass   failed: $fail"
if [ "$fail" -ne 0 ]; then echo "RESULT: FAILED"; exit 1; fi
echo "RESULT: PASSED"
exit 0
