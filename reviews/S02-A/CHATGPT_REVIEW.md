# Независимое научно-техническое ревью S02-A — Octopus 16.4

**Решение: APPROVED, STRICTLY LIMITED TO S02-B.** S02-A принимается **как предварительное исследование численной сходимости атома C**, но **не** как окончательная калибровка физической погрешности или готовая таблица порогов для Ar⁺–SWCNT. Ни один из предложенных допусков `1e-8 Ha`, `1e-6 Ha`, `1e-10` для нормы и `+v/-v` автоматически не утверждается. Исправления, перечисленные ниже, обязательны до S02-C и прежде чем новые допуски станут блокирующими критериями.

- **Review ID:** `S02A-TOLERANCES-2026-11-19`
- **Stage:** `S02-A`; **authorized next stage:** `S02-B` (numerical baseline rt-TDDFT tests only)
- **Claimed public repository commit:** `56c6964e87ff1af8a4bf7bdee2bf91c73d512dd1`
- **Pinned Octopus source:** `3819069c1341e38e3dd4b2a4285f83eff3cfba36` (`16.4`, unmodified)
- **Evidence workspace commit:** `97f2c5c519b371daee8e2b9bb3d05a37f874ad1a`
- **Input reviewed:** supplied `Octopus_S02A_56c6964_Review.tar.gz` with `stages/S02-A/` snapshot; external public GitHub commit page could not be fetched directly. The archive-to-commit provenance therefore rests on the user's exact-commit export; only intra-archive integrity was independently checked.

## 1. Scope and reproduced checks

Inspected: `REVIEW_REQUEST.json`, `STAGE_MANIFEST.json`, `README.md`, both CSVs, `s02_convergence.md`, `s02_provenance.json`, submitted logs, `s02_convergence.sh`, `s02_analyze.py`, `verify_s02_numbers.sh`, `WORK_STATE.md`, `AGENT_CHECKPOINT.json`.

- Every one of **13 files listed in `STAGE_MANIFEST.json`** agrees with its declared SHA-256 and file size.
- **12 distinct CSV cases**, all with reported exit code 0.
- Re-ran `s02_analyze.py` and `verify_s02_numbers.sh` locally on the supplied CSV/Markdown: reported **21/21 checks passed**; Python compiles and both shell scripts pass `bash -n`.
- Independently recalculated (Decimal arithmetic): total-energy spread at R=8 = **53.67054 mHa**; fine-mesh (h=0.30, 0.35, 0.40) spread **3.43131 mHa**; box-radius (R=5–8, h=0.35) spread **19.31266 mHa**; ratio `(E7-E6)/(E8-E7) = 3.6513323`; geometric-tail estimate `[(E8-E7)^2/(E7-E6)] = −0.2788544 mHa`.
- Observed non-monotonicity: E(h=0.35, R=8) lower than E(h=0.30, R=8) by 3.43131 mHa and lower than E(h=0.40, R=8) by 1.82203 mHa.
- These are **consistency checks of exported summary data, not a rerun of Octopus**. The archive does **not** include each run's raw `inp`, `static/info`, `run.log`, the `C.upf` and `Ar.upf` bytes, or the compiled binary.

## 2. Critical and major findings

### M1 — Do not promote an observed spread to an absolute error bound

The statement that absolute energies are “meaningful only to ≈3 mHa” is too strong and not demonstrated. 3.43131 mHa is the observed spread across three spacings, **not** the actual error relative to the continuum or converged reference. Likewise, the report's assertion that `h ≤ 0.30` and `R ≥ 8` suffices for a 1 mHa claim is unsupported; the h=0.30 result is higher than h=0.35 and not demonstrably closer to the converged answer. Rewrite these statements as observations, and do not use them as accuracy guarantees.

**Required:** an expanded grid series (e.g. h=0.30, 0.275, 0.25, with costs assessed first) at R≥8–10, and at least two additional box radii (R=9,10) if affordable. Track the joint h/R dependence, not two independently varying one-dimensional slices alone.

### M2 — Same-grid cancellation is a useful paired design, not proof of accuracy

Agreed: use `ΔQ(h,R,dt) = Q_method_A(h,R,dt) − Q_method_B(h,R,dt)` for *identical* geometry, PP, grid origin, box, dt and trajectory. **Also require** convergence of ΔQ itself under grid refinement, box enlargement, time-step refinement and displacement of the grid origin. Same-grid runs can share systematic discretization errors but do not ensure cancellation, particularly for translating nuclei and nonlocal pseudopotentials.

For later moving-ion tests, explicitly measure *egg-box* / broken translational invariance by shifting an isolated atom relative to the grid by fractions of h (e.g. 0, h/4, h/2) while fixing physical geometry. This is independently known as a real-space-grid hazard and must not be confused with ETF physics.

### M3 — Regression tolerances are not physical tolerances

A repeat run giving identical MD5 of `static/info` is evidence of **serial, same-environment reproducibility for that file only**, not an absolute roundoff or SCF floor. Energy printed to eight decimal places cannot establish a `1e-8 Ha` acceptance threshold. `Tolerance=1e-10` vs default giving the same **printed** energy also does not establish exact equality in unrounded data or disprove all SCF contributions.

**Required:** separate columns `numerical-repeatability`, `discretization-convergence`, `integration-error`, `physical-model-uncertainty`; mark `1e-8 Ha`, `1e-6 Ha`, `1e-10 relative/1000 steps`, and `+v/-v 1e-8 Ha` as **PROVISIONAL / NOT_VALIDATED**. Choose pass/fail thresholds after tests against unrounded outputs and across at least two numerical settings. A stable regression is not evidence of physical correctness.

### M4 — The 0.28 mHa box residual is a model extrapolation only

The computed number is correct **as a geometric-tail model**; the negative sign indicates the model's residual energy correction, and its magnitude is 0.279 mHa. The increments 5→6, 6→7 and 7→8 are not a proof of an asymptotic geometric series. Do not treat 0.28 mHa as a rigorous upper bound. Repeat at R=9 and R=10 and compare fit variants; retain the sign and confidence limitations.

### M5 — Numeric verifier has a real false-negative gap

The header of `verify_s02_numbers.sh` promises to check “every quantitative claim”. It checks **only eight named raw energy rows**, selected aggregate statistics, and mere occurrence of seven tokens in Markdown. **Counterexample reproduced:** on an isolated copy of the supplied dataset, changing `sp0.45_R6.0` total energy from `−5.66292696` to `−5.66392696` left the script at **21/21 PASSED**. This falsifies the comprehensive-coverage claim.

**Required:** parse all Markdown tables for all 12 cases, check every listed energy, eigenvalue, delta, row count, uniqueness of `(h,R)`, control metadata, and derived statistics from CSV; include at least one adversarial mutation test that **must fail**. Avoid hard-coded expected totals without independent raw-data checks. A file-manifest hash validates consistency with the manifest, not the correctness of the scientific numbers.

### M6 — Missing raw records and Ar⁺-specific convergence

Metadata declares C pseudopotential SHA, Ar pseudopotential SHA, `z_valence=8`, `l_max=2`, six Ar projectors and NLCC; however the **actual UPF files are not included**. For an Ar⁺ based on this eight-valence-electron PP, the expected explicit valence count is seven, but the declaration cannot be independently checked from this snapshot. Preserve raw Octopus inputs, `static/info`, `run.log` (preferably compressed) and check PP hashes against bytes. Include an **Ar⁺ ground-state convergence series**, its spin/charge initialization and finite-box convergence before using C-derived thresholds for any Ar⁺/CNT model.

### M7 — Keep physical symmetry expectations conditional

`v=+v` versus `v=−v` does not automatically imply equality of *every* observable in an arbitrary collision geometry. Define the exact time-reversal or spatial symmetry being invoked, match initial states and trajectories, and choose the invariant or transformed observable. Test free Ar⁺ in a symmetric setup before transferring a symmetry threshold to the CNT scattering configuration.

## 3. Answers to the six questions in REVIEW_REQUEST.json

**Q1. Same-mesh differences or converged absolute reference?** **Both, for different purposes.** Paired same-mesh differences are the primary comparison between ETF modes, but these differences must themselves converge versus h/R/dt and grid origin. A converged absolute-reference study is needed for calibrated GS accuracy; no blanket ban on cross-mesh total-energy comparisons (they are precisely what convergence studies use).

**Q2. Explanation for non-monotonicity?** **Plausible, not demonstrated.** Jagged boundaries, PP representation, NLCC, egg-box aliasing and grid-origin effects may contribute. The observed effect does not by itself show a setup error, but it prevents treating the current series as converged. Add grid shifts and finer spacings before claiming cause.

**Q3. `1e-8 Ha` from a single repeat?** **No.** Preserve as a candidate *regression target* only, not an accepted threshold. Verify actual output precision, perturbation tests and repeated runs on multiple inputs (and MPI separately when available).

**Q4. `0.28 mHa` without R9/10?** **Only as an explicitly qualified model estimate, not a bound or final tolerance.** Add at least R9 and preferably R10.

**Q5. Proceed to S02-B?** **Yes, with limited authorization.** S02-B may design and execute baseline *serial CPU* rt-TDDFT norm/time-step tests on unmodified Octopus, explicitly treating all threshold values as provisional. Before approval for S02-C or the first Fortran patch, implement the verifier fix and report the additional convergence controls. No source patch, MPI/GPU, remote SSH or HPC deployment is authorized by this decision.

**Q6. C-only adequate for future Ar⁺ ladder?** **No.** C-only is acceptable as a numerical smoke/initial convergence benchmark. Add Ar⁺ and later Ar⁺–C benchmark convergence with the actual Ar PP before physical thresholds for Ar⁺ are set. As time allows, Ar⁺ GS can be done in parallel with S02-B only under existing local CPU permission and without modifying source code.

## 4. Acceptance criteria for S02-B

1. **Unmodified baseline only.** Select and record the real-time propagator (e.g. ETRS), XC, spin, PP, grid, radius, dt, run length and initial perturbation. Avoid claiming that a stationary, unexcited atom alone constitutes a meaningful TDDFT stress test.
2. Measure per-orbital norm and integrated electron number versus time (with absorbing boundaries **disabled**) for at least three timesteps and a separate no-field control. Record `max_t |N(t)-N(0)|`, not just an endpoint.
3. Compare an observable trajectory at dt, dt/2 and dt/4 at a common physical end time; verify systematic time-step convergence, not just one arbitrarily chosen threshold.
4. Compare paired differences across at least two spacings and grid-origin shifts. Report drift, convergence order if extractable, and limitations.
5. Fix the numeric verifier's false-negative and add a mutation test; preserve full raw run artifacts or a documented, reproducible subset with pseudopotential hashes and CMake/Octopus provenance.
6. Submit `reports/s02b_td_convergence.md`, CSV, test runner, actual logs, `AGENT_CHECKPOINT.json`, and `review/PENDING.json`; do not claim validation of moving Ar⁺, ETF, traveling PP, forces or total-energy conservation for driven ions.

## 5. Review decision and boundaries

**APPROVED FOR S02-B ONLY** (conditional acceptance of S02-A's *measured observations*, **not** of its proposed numerical thresholds). The next stage remains limited to **local, unmodified, serial CPU Octopus 16.4** and test development. All Fortran/physics patches (S04–S07), MPI/GPU, remote cluster execution, publication-grade claims, and production Ar⁺–SWCNT simulations are **not approved**. A new external review is mandatory before expanding scope.

Human sign-off in the local workspace remains mandatory; publishing this file or recording `DECISION.json` in GitHub does **not** invoke `review_ctl.py`.

## 6. External sources used for methodological cross-check

- Octopus official tutorial, *Total energy convergence*: https://www.octopus-code.org/documentation/main/tutorial/basics/total_energy_convergence/ — grid spacing and box size must be converged for the desired observable.
- Octopus tutorial on spatial discretization: https://octopus-code.org/documentation/13/manual/basics/discretization/ — convergence requires explicit spacing selection.
- Andrade et al., *Real-space grids and the Octopus code as tools for the development of new simulation approaches for electronic systems*, PCCP (2015): https://pubs.rsc.org/en/content/articlehtml/2015/cp/c5cp00351b — egg-box / translational invariance and real-space discretization limitations.

**This review does not certify the scientific correctness of an ETF/traveling-NLPP implementation, which has not been supplied.**
