[Home](../README.md) / Installation

# Installation

This page installs the interface into NewtonX and checks that it works. It takes a few minutes.

## Requirements

| Program | Version | Notes |
|---|---|---|
| NewtonX | 2.x (tested 2.4) | `$NX` must point to its `bin` folder. |
| Q-Chem | 5.4 or later (tested 5.4.1) | `qchem` on your `PATH` and `$QCSCRATCH` set. |
| Perl | 5.14 or later | Only core modules are used. |
| Python 3 with NumPy and Matplotlib | any recent | NumPy for the tests and tools; Matplotlib only for the plots. |

## Install

```bash
perl nx/install.pl                      # uses $NX
perl nx/install.pl --nx /path/to/NX/bin # or name the folder explicitly
perl nx/install.pl --dry-run            # report what would change, change nothing
```

The installer changes your NewtonX installation (`$NX/lib/colib_perl.pm` and `$NX`), so you need write access to it. If NewtonX is shared with others, install into your own copy: `cp -r` the NewtonX folder and point `$NX` at the copy's `bin`.

The installer:

1. Registers Q-Chem as `prog = 22` in `$NX/lib/colib_perl.pm`. It adds the five pieces the NewtonX manual asks of a new interface:
   - `prog_config`: the program definition;
   - `check_thirdparty`: at the start of a trajectory, checks `qchem`, `$QCSCRATCH`, the templates and `vdoth`, and prints your settings in `RESULTS/nx.log`;
   - `read_credits`, `load_defaults_tpp` and `test_list`.
2. Copies `run-qchem-eom.pl` (dynamics) and `run-qchem-eom-initcond.pl` ([initial conditions and spectra](initial-conditions.md)) to `$NX`, executable.
3. Copies the NewtonX test case `MD-QCHEM-EOMIP-NAD` into `$NX/../test-nx`, if that folder exists (it does in a standard NewtonX installation).

**Safe to re-run.** The added code sits between `# >>> NX-QCHEM` and `# <<< NX-QCHEM` markers, and running the installer again replaces it; do this after every update of this repository. An older, hand-added `prog 22` block is replaced too. Before changing `colib_perl.pm` the installer saves a time-stamped backup. It checks that the patched file loads before swapping it in with an atomic rename; if it does not load, the original is left untouched.

## Check the installation

```bash
tests/run_tests.sh
```

This replays real Q-Chem outputs through the interface with NewtonX's own `escalar` program. It needs `$NX`, takes about 10 seconds, and does not run Q-Chem. Every line should read `PASS`.

To test the whole chain, including Q-Chem, run NewtonX's test `MD-QCHEM-EOMIP-NAD`, a 5-step methane-cation trajectory that takes a few minutes on 4 cores. Without a `test.inp`, `test-nx.pl` runs every NewtonX test, so name the Q-Chem test, which the installer adds as the last one:

```bash
mkdir nxtest && cd nxtest
perl -I$NX/lib -Mcolib_perl -e 'print scalar test_list(-1), "\n"' > test.inp   # number of the last test
$NX/test-nx.pl > test-nx.log
```

`test-nx.log` should end with `Normal termination of all tests.` It may add that `dyn.out` differs from the standard results with "only minor numerical differences": multithreaded Q-Chem changes the last digits of the amplitudes, and this is expected.

## Updating

Pull the repository and run `perl nx/install.pl` again. Running trajectories call `$NX/run-qchem-eom.pl` at every step, so they switch to the new version at their next step. To keep a running batch on the old version, update a separate copy of NewtonX instead.

## See also

- [Your first trajectory](first-trajectory.md)
- [Troubleshooting](troubleshooting.md)
