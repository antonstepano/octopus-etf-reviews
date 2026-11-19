# S02-A — Numerical convergence study and tolerance derivation

**Stage:** S02 (test-ladder design), sub-task A.
**Status:** COMPLETED — measurements real, all exit codes recorded.
**Authorized by:** `review/APPROVED.json` (`S01-SOURCE-AUDIT-2026-11-19`), scope "S02 test design only".
**Source:** `octopus-baseline` @ `3819069c1341e38e3dd4b2a4285f83eff3cfba36` (tag 16.4), **unmodified**.
**Provenance:** `reports/s02_provenance.json`.
**Raw data:** `reports/s02_convergence.csv`, logs `reports/s02_convergence_run.log`, `reports/s02_analysis.log`.

---

## 1. Why this study exists

Review Q6 requires that every tolerance in the S02 test ladder be derived from a
documented convergence study, not invented. This sub-task produces that derivation
for the smallest rung of the ladder (a single C atom, NC pseudo-dojo PBE) and, more
importantly, establishes **which kind of comparison is even resolvable** on this
mesh family.

It is a measurement of the *baseline* code. It says nothing about Ar⁺, CNTs, TDDFT
or ETF.

## 2. Setup

| Item | Value |
|---|---|
| System | 1 C atom at origin, `BoxShape = sphere`, `PeriodicDimensions = 0` |
| Pseudopotential | `nc-sr-05_pbe_standard/C.upf`, NC, PBE, z_valence 4.0, NLCC on, sha256 `f828e50a…` |
| `ExtraStates` | 2 |
| SCF tolerance | Octopus default (see §5 for the tightened control) |
| Binary | `build/baseline-cmake/octopus`, gfortran 11.4.0, `-O3`, serial, no MPI/OpenMP |
| Units | Hartree / bohr |

Three series, 12 runs, all `exit_code = 0`:

1. spacing `h ∈ {0.50, 0.45, 0.40, 0.35, 0.30}` at fixed `R = 6.0` bohr;
2. box radius `R ∈ {5, 6, 7, 8}` bohr at fixed `h = 0.35`;
3. spacing `h ∈ {0.50, 0.45, 0.40, 0.35, 0.30}` at fixed `R = 8.0` bohr.

Series 3 was added after series 1 showed that at `R = 6.0` the box-truncation error
(~5 mHa) exceeds the fine-mesh spacing differences, so series 1 alone cannot
separate the two error sources. This is recorded rather than hidden: the first
version of the script had only series 1 and 2.

## 3. Results

### 3.1 Spacing at fixed R = 8.0 bohr (series 3)

| h [bohr] | E_total [Ha] | ΔE vs previous [mHa] |
|---:|---:|---:|
| 0.30 | -5.68555889 | — |
| 0.35 | -5.68899020 | -3.431 |
| 0.40 | -5.68716817 | +1.822 |
| 0.45 | -5.66790933 | +19.259 |
| 0.50 | -5.63531966 | +32.590 |

**The convergence is non-monotonic.** `E(0.35)` lies below both `E(0.30)` and
`E(0.40)`. This is not SCF noise — see §5.

### 3.2 Box radius at fixed h = 0.35 bohr (series 2)

| R [bohr] | E_total [Ha] | ΔE vs previous [mHa] |
|---:|---:|---:|
| 5 | -5.66967754 | — |
| 6 | -5.68425426 | -14.577 |
| 7 | -5.68797201 | -3.718 |
| 8 | -5.68899020 | -1.018 |

Monotonic, geometric tail: `Δ(6→7)/Δ(7→8) = 3.65`, so the residual box error at
`R = 8` is ≈ **0.28 mHa** by geometric extrapolation. This extrapolation is an
estimate, not a verified bound.

### 3.3 Eigenvalues at R = 8.0

| h | ε(2s) [Ha] | ε(2p) [Ha] |
|---:|---:|---:|
| 0.30 | -0.503586 | -0.192741 |
| 0.35 | -0.502820 | -0.193179 |
| 0.40 | -0.504653 | -0.192528 |
| 0.45 | -0.511501 | -0.189240 |
| 0.50 | -0.521055 | -0.184527 |

Same non-monotonic pattern at the 1–2 mHa level between `h = 0.30…0.40`.

## 4. Derived numerical floor

| Quantity | Value | Basis |
|---|---|---|
| Absolute total energy, spacing-induced spread (R = 8) | **53.7 mHa** over h = 0.30…0.50 | series 3 |
| Absolute total energy, fine-mesh spread (h = 0.30…0.40) | **3.4 mHa** | series 3 |
| Absolute total energy, box-induced spread (R = 5…8) | **19.3 mHa** | series 2 |
| Residual box error at R = 8 (extrapolated) | ≈ 0.28 mHa | geometric tail, **estimate** |
| Run-to-run reproducibility, same input | **0 (bitwise identical)** | §5 |

**Consequence for the test ladder — the central result of S02-A:**

> Absolute total energies on this mesh family are only meaningful to ≈ 3 mHa
> (≈ 80 meV). Any claim of a physical energy difference smaller than that,
> based on *absolute* energies at *different* meshes, is unresolvable and must
> be rejected.

> Comparisons at **fixed mesh** are limited only by SCF tolerance and are
> bitwise reproducible in serial. Therefore the ETF test ladder must be built
> on **same-mesh differences** (`v = 0` vs `v = +v` vs `v = -v`, `legacy` vs
> `initial_etf` vs `traveling_pp` at identical grid/dt/PP/trajectory), not on
> absolute energies across meshes.

This is exactly the structure review Q4/Q6 asked for, and it is now backed by
numbers rather than assertion.

## 5. Controls that rule out the obvious alternative explanations

Machine-readable: `reports/s02_controls.csv`.

| Control | Command | Result | Evidence |
|---|---|---|---|
| Is the non-monotonicity SCF noise? | `sp0.30_R8.0` rerun with `Tolerance = 1.0e-10` (default vs tight) | `-5.68555889` in **both** cases, `delta = 0.00e+00` → **not** SCF noise; it is discretisation | `results/s02_convergence/sp0.30_R8.0_tight/run.log` |
| Is the run deterministic? | `sp0.35_R8.0` rerun, `diff` of `static/info` | **bitwise identical**, md5 `70944263899de41c370308951abe6484` for both → serial reproducibility floor = 0 | `results/s02_convergence/sp0.35_R8.0_repeat/run.log` |
| Does the locale corrupt the data? | first run produced `walltime = 0,48` (decimal comma) | fixed by `export LC_ALL=C`; the buggy first CSV was discarded, not reported | `reports/s02_convergence_run.log` |

The first version of `tests/s02_convergence.sh` also mis-parsed eigenvalues
(column 2 instead of 3, and a regex that never matched the `--` spin column).
The script aborted with `RESULT: FAILED (unparseable energy in CSV)`; the fix is
in the committed version. This is recorded because a parser that silently emits
`NA` would have produced a fake "PASSED".

## 6. Proposed tolerances for the S02 test ladder

These are **proposals for review**, not approved thresholds.

| Observable | Proposed tolerance | Justification |
|---|---|---|
| Same-mesh total-energy difference, serial, fixed dt | `1e-8 Ha` (roundoff) | bitwise reproducibility observed; leave 2 orders of margin |
| Same-mesh eigenvalue difference | `1e-6 Ha` | SCF tolerance floor |
| Absolute energy vs a different mesh | **do not compare**; if unavoidable, `≥ 5 mHa` and label `UNVERIFIED` | §4 |
| Norm conservation in rt-TDDFT | `1e-10` relative per 1000 steps | to be measured in S02-B, not assumed here |
| `v = +v` vs `v = -v` symmetry | `1e-8 Ha` on same mesh | follows from same-mesh reproducibility; must be *tested*, not assumed |

The rt-TDDFT and symmetry rows are **NOT_RUN** — they belong to S02-B/C and are
listed here only so the ladder is explicit.

## 7. What this does NOT establish

- No Ar⁺, no CNT, no TDDFT, no ETF, no moving ion was simulated.
- The 0.28 mHa box residual is an extrapolation, not a verified bound.
- The non-monotonic spacing convergence is *observed*, not *explained*. A
  plausible cause (jagged sphere mask + hard NLCC pseudo on a regular grid) is a
  hypothesis; it was not tested and must not be cited as a finding.
- Nothing here validates any physics of the project.

## 8. Next bounded task (S02-B)

Same-mesh rt-TDDFT reproducibility and norm conservation on the C atom
(`CalculationMode = td`, fixed dt, 3 dt values), to fill the two `NOT_RUN` rows of
§6. No source changes. Requires no new authorization beyond the existing S02 scope.
