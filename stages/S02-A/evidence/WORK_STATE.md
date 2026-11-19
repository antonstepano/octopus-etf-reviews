# WORK_STATE — Octopus ETF development

## Current status
- Stage: S02 (test-ladder design) — sub-task **S02-A completed**; S02-B next
- Status: **NEEDS_REVIEW** — S02-A tolerance derivation submitted (`review/PENDING.json`, `S02A-TOLERANCES-2026-11-19`)
- Source checkout: `octopus-baseline` @ tag `16.4`, commit `3819069c1341e38e3dd4b2a4285f83eff3cfba36` (detached HEAD, tree clean)
- Fork checkout: `octopus-patched` @ same commit, tree clean, **no source modifications yet** (still true after S01)
- Baseline build: **PASSED** (serial, GNU 11.4.0, Ninja, Release)
- Patched build: NOT_RUN (no patch exists yet)
- Physical validation: NOT_RUN (only a numerical smoke test, see below)
- External review: S00 **APPROVED**; S01 **APPROVED FOR S02 TEST DESIGN ONLY** (`review/APPROVED.json`, `review/CHATGPT_S01_REVIEW.md`)

## Environment (verified 2026-11-19)
| Component | Value | Status |
|---|---|---|
| gcc / gfortran / g++ | 11.4.0 (Ubuntu 22.04) | OK |
| CMake | 3.22.1 | OK |
| Ninja | 1.10.1 | OK |
| Libxc | 5.1.7 (with 2nd derivatives) | OK |
| BLAS/LAPACK | Intel MKL 2024.2 (`libmkl_gf_lp64`) | OK |
| GSL | 2.7.1 | OK |
| FFTW | serial (no MPI variants) | PARTIAL |
| OpenMPI | 4.1.7a1 | **BLOCKED** |
| `mpif90` | resolves to **nvfortran** (NVIDIA HPC SDK) | **BLOCKED** |
| SPARSKIT | `/usr/lib/libskit.so` has unresolved `afun_/dfun_/fung_/…` | **BROKEN** |
| Hardware | 24 cores, 62 GB RAM | OK |

## Blockers (recorded, not worked around silently)
1. **MPI build impossible locally.** `OCTOPUS_MPI=OFF`; `FFTW_*_MPI_LIB-NOTFOUND`; `mpif90` is an
   nvfortran wrapper, incompatible with the gfortran toolchain used for the serial build.
   Consequence: all S02+ MPI tests are `NOT_RUN` until a gfortran-based MPI wrapper
   (`mpif90.openmpi` / `mpifort`) and FFTW-MPI are provided. **No HPC access attempted.**
2. **System SPARSKIT is unusable.** Linking `oct-unfold` failed with undefined references inside
   `/usr/lib/libskit.so`. Worked around *without touching sources* via
   `-DCMAKE_DISABLE_FIND_PACKAGE_SPARSKIT=ON`. Octopus builds and runs without it; the
   `oct-unfold` utility is therefore unavailable in this build.

## Evidence (commands, exit codes, logs)
All logs in `reports/`.

1. `git -C octopus-baseline rev-parse HEAD` → `3819069c…`; `git describe --tags` → `16.4`; `git status --porcelain` → empty.
2. `cmake -S octopus-baseline -B build/baseline-cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_DISABLE_FIND_PACKAGE_SPARSKIT=ON`
   → **EXIT=0** — `reports/s00_configure_baseline.log`
3. `ninja -C build/baseline-cmake -j24` → **EXIT=0**, WALL=171.76 s, MAXRSS=729 MB, `[1034/1034] Linking Fortran executable octopus`
   — `reports/s00_build_baseline.log`
4. `./build/baseline-cmake/octopus --version` → `octopus 16.4 (git commit 3819069)`, EXIT=0 — `reports/s00_octopus_version.log`
5. Smoke run (single C atom, NC pseudo-dojo `C.upf`, sphere R=5.0 bohr, spacing 0.45, gs):
   - attempt 1: **FAILED** — `Cannot open variables file: /usr/local/share/octopus/variables` (install prefix not populated)
   - attempt 2: **FAILED** — `OCTOPUS_SHARE=octopus-baseline/share` → `variables` not there (it is generated at build time)
   - attempt 3: **PASSED** with `OCTOPUS_SHARE=build/baseline-cmake/share`
   - result: `SCF converged in 14 iterations`, `Total electronic charge = 4.000` (correct for 4 C valence e⁻),
     eigenvalues 2s = −0.4934 Ha, 2p = −0.1468 Ha (×3, occ 0.667 each), walltime 0.52 s
   - log: `results/s00_smoke/run.log`, input: `results/s00_smoke/inp`

**Interpretation limit:** item 5 proves the binary executes real SCF physics and conserves electron
number. It is **not** a physical validation of the project's science (no Ar⁺, no CNT, no TDDFT,
no ETF). Do not cite it as a scientific result.

## S01 result — source audit (COMPLETED, verified)

Deliverable: `reports/s01_call_graph.md` (231 lines, 49 distinct `file:line` citations).
Mechanical check: `tests/verify_s01_refs.sh` → **PASSED**, 65 references checked, 0 failures,
0 uncovered citations — `reports/s01_verify_refs.log`.

### Negative findings (these size the work)
- **N1** No ETF / translation-factor code exists in 16.4: `grep -rniE '\betf\b' src --include=*.F90 | wc -l` → `0`.
- **N2** The only per-projector phase array is the k-point / vector-potential / spiral-BC phase
  (`projector.F90:170 projector_init_phases`, `exp(-M_zI*kr)` at `:235`). It is not an ion-velocity phase.
- **N3** For a **gamma-only finite system** (our Ar⁺ + SWCNT case) the projector phase array is
  **never allocated**: guard at `hamiltonian_elec.F90:991`, early `return` at `phase.F90:143`.
  S05 cannot "add a term" — the allocation path itself must be opened.
- **N4** `nphase` is a hard-coded 1-or-3 switch (spiral BC), not a general phase-slot count
  (`projector.F90:187-188`, `nonlocal_pseudopotential.F90:76`, `hamiltonian_elec.F90:1020-1021`).
- **N5** Prescribed ion trajectories **already exist**: `IonsConstantVelocity` (`ion_dynamics.F90:241`),
  `IonsTimeDependentDisplacements` (`:271`), driven propagation at `:740`. S06 needs no new input machinery.
- **N6** No velocity-dependent force term exists (`forces_inc.F90:195`); it must be derived, not inherited.

### Patch surface identified
| Stage | File | Procedure / line |
|---|---|---|
| S04 | `src/td/td.F90` | `td_init_with_wavefunctions` :748 + new input block |
| S05 | `src/hamiltonian/projector.F90` | `projector_init_phases` :170 |
| S05 | `src/hamiltonian/hamiltonian_elec.F90` | `build_phase` :991, :1018 |
| S05 | `src/hamiltonian/nonlocal_pseudopotential.F90` | `nphase` :76 |
| S05 | `src/hamiltonian/hamiltonian_elec_inc.F90` | `apply_batch` :199 |
| S06 | `src/td/propagator_elec.F90` | :473 (harness only) |
| S07 | `src/electrons/forces_inc.F90` | :195 |

### Risks recorded for review
1. **Two parallel nonlocal implementations**: `ep%proj` + `project_psi_batch`
   (`hamiltonian_elec_inc.F90:199`) vs the packed `vnl%*` path. Patching only one may silently diverge.
2. **Sign/frame of the ETF phase** relative to `exp(-i k·diff)` must be derived, not guessed.
3. **Extending `nphase`** touches GPU buffer sizing (`buff_projector_phases`) and spiral-BC indexing.

## S02-A result — numerical convergence study (COMPLETED, verified)

Deliverables:
- `tests/s02_convergence.sh` — 12 baseline runs (3 series), `LC_ALL=C`, exit codes recorded
- `tests/s02_analyze.py` — derives the floor from the CSV only
- `tests/verify_s02_numbers.sh` — **PASSED**, 21 checks, 0 failures (`reports/s02_verify_numbers.log`)
- `reports/s02_convergence.csv`, `reports/s02_controls.csv`, `reports/s02_convergence.md`,
  `reports/s02_provenance.json`

### Measured (C atom, NC pseudo-dojo PBE, unmodified baseline binary)
| Quantity | Value |
|---|---|
| spacing spread, h = 0.30…0.50 at R = 8 | 53.7 mHa |
| fine-mesh spread, h = 0.30…0.40 at R = 8 | **3.4 mHa** |
| box spread, R = 5…8 at h = 0.35 | 19.3 mHa |
| box tail ratio Δ(6→7)/Δ(7→8) | 3.65 → residual at R = 8 ≈ 0.28 mHa (extrapolation, not a bound) |
| run-to-run reproducibility, same input | **bitwise identical** (md5 match) |
| SCF tolerance 1e-10 vs default | delta = 0.00e+00 |

### Central conclusion (drives the whole ladder)
Absolute total energies on this mesh family are meaningful only to ≈ 3 mHa (≈ 80 meV), and the
spacing convergence is **non-monotonic** (E(0.35) < both E(0.30) and E(0.40)). Therefore the ETF
test ladder must be built on **same-mesh differences** (`v=0` vs `+v` vs `-v`; `legacy` vs
`initial_etf` vs `traveling_pp` at identical grid/dt/PP/trajectory), never on absolute energies
across meshes. Same-mesh comparisons are bitwise reproducible in serial.

### Verified side-finding
`Ar.upf` (pseudo-dojo `nc-sr-05_pbe_standard`) has `z_valence = 8.00`, `pseudo_type = NC`,
`core_correction = T`, `l_max = 2`, `number_of_proj = 6`, sha256 `e366a9ed…`. This **confirms**
the PHYSICS_TASK_RU statement that Ar⁺ carries 7 valence electrons for this PP — checked against
the file, not assumed.

### Honest limits
- No Ar⁺, no CNT, no TDDFT, no ETF, no moving ion was simulated.
- The non-monotonic spacing convergence is *observed*, not *explained*; the jagged-sphere-mask
  hypothesis was not tested and must not be cited as a finding.
- The 0.28 mHa box residual is a geometric extrapolation, not a verified bound.
- Two parser bugs in the first script version (decimal comma from ru_RU locale; wrong eigenvalue
  column) were caught by the script's own failure path and fixed; the bad CSV was discarded.

## Next bounded task (S02-B) — blocked on S02-A review
Same-mesh rt-TDDFT reproducibility and norm conservation on the C atom
(`CalculationMode = td`, three dt values), to fill the two `NOT_RUN` tolerance rows of
`reports/s02_convergence.md` §6. No source changes; within the existing S02 authorization.

## History
- 2026-11-19 19:07 — session start; read AGENT.md, agent/PHYSICS_TASK_RU.md, WORK_STATE.md, AGENT_CHECKPOINT.json.
  Found prior configure log truncated at etsf-io, no `CMakeCache.txt` → configure had never completed.
- 2026-11-19 19:10 — verified base commit/tag and toolchain; discovered `mpif90 → nvfortran` blocker.
- 2026-11-19 19:15 — configure completed EXIT=0 (first attempt); build failed at `oct-unfold` link (broken system SPARSKIT).
- 2026-11-19 19:20 — reconfigured with `CMAKE_DISABLE_FIND_PACKAGE_SPARSKIT=ON`; build EXIT=0 in 171.76 s.
- 2026-11-19 19:22 — `octopus --version` OK; C-atom SCF smoke test PASSED (charge 4.000, 14 SCF iters).
- 2026-11-19 19:25 — workspace root had no git repo; initialized one with `.gitignore` for `build/`,
  `octopus-baseline/`, `octopus-patched/` and Octopus binary run artifacts. Checkpoint updated.
- 2026-11-19 20:00 — S01 started after reading `review/APPROVED.json` (S00 approved, scope = S01 audit only).
- 2026-11-19 20:05 — `rg` unavailable in this environment; switched to `grep -rn` (no install attempted).
- 2026-11-19 20:10 — traced the full chain: `td_run` → `propagator_elec_dt` → `hamiltonian_elec_epot_generate`
  → `vnl%build` → `hamiltonian_elec_update` → `projector_init_phases`; and the force/energy branches.
- 2026-11-19 20:12 — wrote `reports/s01_call_graph.md`; first draft had 6 wrong line numbers, found by the
  verifier and corrected (kept as evidence that the check is real, not decorative).
- 2026-11-19 20:15 — `tests/verify_s01_refs.sh` PASSED: 65 references, 0 failures, 0 uncovered citations.
- 2026-11-19 20:16 — `review/latest.patch` (286 MB, 9M lines, full upstream history dump) added to
  `.gitignore`; it is not a project deliverable and must not enter the repository.
- 2026-11-19 20:18 — checkpoint updated to S01 / NEEDS_REVIEW; S01 review requested.

## External ChatGPT review — S01

Decision: APPROVED FOR S02 TEST DESIGN ONLY.

Before starting S02, read the complete external review:
review/CHATGPT_S01_REVIEW.md

Requirements:
- Follow all seven review recommendations.
- Design tests before modifying Fortran.
- Keep legacy Octopus behavior unchanged by default.
- Do not implement S04-S07 before their approval.
- Do not start MPI/GPU/HPC builds without an approved plan.
- Preserve all review findings in subsequent work.

Next authorized stage: S02 — physical validation test design.

## History — S02
- 2026-11-19 20:31 — session start; read AGENT.md, PHYSICS_TASK_RU.md, WORK_STATE.md,
  AGENT_CHECKPOINT.json, review/APPROVED.json, review/CHATGPT_S01_REVIEW.md.
- 2026-11-19 20:34 — chose S02-A (convergence study) as the one bounded deliverable; no source edits.
- 2026-11-19 20:38 — wrote `tests/s02_convergence.sh`; first run FAILED its own check
  (`RESULT: FAILED (unparseable energy in CSV)`) due to ru_RU decimal comma and a wrong
  eigenvalue column. Fixed with `LC_ALL=C` and field 3; bad CSV discarded.
- 2026-11-19 20:41 — series 1 (R=6) showed box error masking spacing convergence; added series 3
  (R=8). 12 runs, all exit 0.
- 2026-11-19 20:44 — control C1: `Tolerance=1e-10` reproduces the default energy exactly
  (delta 0.00e+00) → non-monotonicity is discretisation, not SCF noise.
- 2026-11-19 20:46 — control C2: repeat run bitwise identical (md5 match) → same-mesh floor = 0.
- 2026-11-19 20:50 — wrote `reports/s02_convergence.md`, `reports/s02_provenance.json`,
  `tests/s02_analyze.py`.
- 2026-11-19 20:55 — wrote `tests/verify_s02_numbers.sh`; it FAILED 4 checks on the first pass
  (wrong series-2 range, sign of the residual, and Unicode minus U+2212 in the report tables
  breaking machine comparison). All four fixed; now 21/21 PASSED.
- 2026-11-19 21:00 — checkpoint updated to S02 / IN_PROGRESS; commit made.
- 2026-11-19 21:05 — S02-A submitted for external review: `review/PENDING.json`
  (`S02A-TOLERANCES-2026-11-19`), 6 questions, 5 proposed tolerances. Previous S01 request archived as
  `review/PENDING.S01.answered.json`. Checkpoint status -> NEEDS_REVIEW. No further work until answered.
