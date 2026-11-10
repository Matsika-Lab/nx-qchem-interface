[Home](../README.md) / Development and testing

# Development and testing

This page describes the test suite: how to run it, how it works without Q-Chem, and how to add a test. Run it after every change to `run-qchem-eom.pl` or `run-qchem-eom-initcond.pl`.

## Running the tests

```bash
tests/run_tests.sh          # needs $NX; about 10 s; no Q-Chem run
KEEP=1 tests/run_tests.sh   # keep the work folders and print their path
```

`$NX` must point to the `bin` folder of a NewtonX installation, 2.4 or 2.6; the tests use its `escalar` and `colib_perl.pm`. Each test prints `PASS` or `FAIL`, and the last line counts them. The script exits with 0 only if every test passes.

## How the tests work

The tests replay real Q-Chem outputs through the interface, step by step:

- **Stand-in Q-Chem.** [`tests/fake_qchem/qchem`](../tests/fake_qchem/qchem) is put first on `PATH`. It copies the archived output named in `$REPLAY_OUT` (gzipped or plain) to the output file the interface asked for, and exits with `$REPLAY_RC` (default 0).
- **One step at a time.** `step` in `run_tests.sh` writes `control.d` for the step (atoms, step number, states, active state, time) and runs the interface in a `TEMP` folder. Its output goes to `snap/<time>.log`, and `nad_vectors` is copied to `snap/<time>.nadv`.
- **Sign checks.** [`tests/check_phase.py`](../tests/check_phase.py) compares every coupling with the last non-zero value of the same pair and counts sign inconsistencies.

## What the tests cover

| Area | Tests |
|---|---|
| Coupling signs | continuity across hops (5-fluorouracil cation); alignment to the stored reference; weak couplings (below 10⁻³ a.u.) left alone; NewtonX 2.6 `phase_correction` keeps the interface's signs |
| Coupling modes | `nx` (NewtonX's pair selection), `full`, `carry`, `active` |
| Step types | gradient-only steps (`vdoth = 2`, `JOB_AD`, adiabatic steps from `THRES`); gradient reuse after a hop |
| Error handling | template and `qchem.par` checks, failed and unconverged Q-Chem jobs, missing jobs, `vdoth`, EOM-EE state below the reference, `scf_check` |
| Other | the archive; initial conditions for EE, SF, IP and EA (`run-qchem-eom-initcond.pl`); `tools/qchem_freq_to_nx.py`; the documentation templates match the example inputs |

## Test data

Each folder in [`tests/data/`](../tests/data) is one case: the Q-Chem template (`JOB_NAD/qchem.inp`), the geometry, and the archived Q-Chem outputs of consecutive steps in `outputs/<time>.out.gz`. They come from real trajectories, for example `fluorouracil_active` from the 5-fluorouracil cation run and `methyl_ea_weak` from the methyl radical example.

## Adding a test

1. Put the case in `tests/data/<name>/`: `JOB_NAD/qchem.inp`, `geom`, and the outputs under `outputs/`, gzipped, named by their time in fs (`0.0000.out.gz`, …). Take them from `INFO_RESTART/qchem_outputs/` of a real run.
2. In `run_tests.sh`, start a trajectory with `d=$(new_traj <name> <label> ["key = value" …])`; the optional arguments become `qchem.par`.
3. Run all steps with `replay $d <name>`, or single steps with `step $d <output> <istep>`.
4. Check the result with `ok "<what passed>"` or `bad "<what failed>"`. Check log lines in `$d/../snap/<time>.log` with `grep`, and vectors in `$d/../snap/<time>.nadv` with NumPy.
5. Keep the case small: a few steps, and only the outputs the test needs.

## See also

- [Outputs and plots](outputs.md): what a run writes
- [Validation](validation.md): results of the tests and of real runs
- [Troubleshooting](troubleshooting.md): the messages the error tests check
