[Home](../README.md) / Troubleshooting

# Troubleshooting

Warnings and per-step reports from the interface start with `run-qchem-eom.pl:` and appear in `RESULTS/nx.log`. An error that stops the run appears in `DEBUG/runnx.error`; `nx.log` only points there. The last Q-Chem input and output of a failed step are in `DEBUG/TEMP/qchem.inp` and `DEBUG/TEMP/qchem.out`.

## Error messages

| Message | What to do |
|---|---|
| `qchem is not in your PATH` or `$QCSCRATCH is not defined` | Load Q-Chem and set `QCSCRATCH` in the shell or job script that starts NewtonX. |
| `Cannot find a Q-Chem template` or `Q-Chem template '…' not found` | Put the template in `JOB_NAD/qchem.inp` (and `JOB_AD/qchem.inp` for initial conditions). |
| `must contain 'SYM_IGNORE TRUE'` | Add `SYM_IGNORE TRUE` to the `$rem` section of the template. See [Methods](methods/README.md#keywords-shared-by-all-methods). |
| `must contain 'CALC_NAC 2'` | Add `CALC_NAC 2` to `JOB_NAD/qchem.inp`, or set `vdoth = 2` for couplings from energies. See [Couplings](couplings.md). |
| `No charge/multiplicity line after $molecule` | Put the reference charge and multiplicity on the line right after `$molecule`. |
| `Unknown keyword '…' in qchem.par`, `Cannot read line in qchem.par`, or a message about a value (`nt must be …`, `scf_check must be …`) | Fix that line of `qchem.par`; see the [Settings reference](par-reference.md). |
| `nac_mode must be nx, full, carry or active` | Use one of these four values. |
| `vdoth = … is not supported` | Use `vdoth = 0` (coupling vectors) or `vdoth = 2` (Baeck-An) in `sh.inp`. |
| `Q-Chem returned a non-zero exit code` followed by `Q-Chem reports: …` | The quoted line is Q-Chem's own reason. `CCSD iterations did not converge` usually means the threshold is too tight: try `CC_CONVERGENCE 8`. For memory errors, raise `MEM_TOTAL` and `CC_MEMORY`. |
| `Q-Chem job n (CC_STATE_TO_OPT [1,k]) did not finish normally` | Open `DEBUG/TEMP/qchem.out` for Q-Chem's error. Common causes are memory and scratch space. |
| `Stopping on a Q-Chem convergence failure` | Look at that step's output. Tighter thresholds, more iterations or a smaller time step usually help. `stop_on_unconverged = 0` continues anyway, at your own risk. |
| `Expected at least n EOM states` | Ask for at least `nstat` states in the template. |
| `No gradient found for the active state` | Q-Chem did not print the gradient of the active state; check that step's output in `DEBUG/TEMP/qchem.out`. |
| `geom has n atoms, control.d says m` | `nat` in `control.dyn` does not match `geom`. |
| `nfs = … needs n …_STATES` (initial conditions) | Ask for `nfs − 1` states (EE, IP, EA) or `nfs` (SF) in `JOB_AD/qchem.inp`. |
| `has no IP_STATES, EA_STATES, EE_STATES or SF_STATES` (initial conditions) | Initial conditions need one of these keywords; spin-specific keywords such as `EE_SINGLETS` are not read. |
| `only transitions from state 1` or `ics_flg = y … is not supported` (initial conditions) | Set `nis = 1` and `ics_flg = n` in `initqp_input`. |
| `Expected n Q-Chem job(s) … found m` | One job of a multi-job step did not run. Check `DEBUG/TEMP/qchem.out`. |
| `Coupling i-j missing` | Q-Chem did not print a coupling it should have. Check the output for a failed response calculation. |
| `Hopping probability larger than one.` (from NewtonX) | The trajectory is close to a conical intersection. Use a smaller `dt` in `control.dyn` or more substeps (`ms` in `sh.inp`). |
| `/usr/bin/env: 'perl\r'` | The script has Windows line endings, usually after a download through Windows. Convert it with `sed -i 's/\r$//' run-qchem-eom.pl run-qchem-eom-initcond.pl`, then run `perl nx/install.pl` again. |

## Warnings

| Warning | Meaning |
|---|---|
| `EOM-SF coupling vectors are computed by Q-Chem but are not documented` | See [EOM-SF](methods/eom-sf.md#caveats). |
| `coupling pair k (states i-j) is nearly orthogonal to its stored reference` | The sign of that coupling after a hop is uncertain. Occasional warnings are normal near intersections; frequent ones suggest `nac_mode = full`. See [Couplings](couplings.md#coupling-signs). |
| `WARNING: Q-Chem job n reports: …` | Q-Chem's convergence message. With `stop_on_unconverged = 0` the run continues; otherwise it stops next. |
| `the SCF reference followed from the previous step is … eV above a fresh-guess SCF solution` | Two SCF solutions of an open-shell (UHF) reference have crossed, and the trajectory follows the higher one. Stability analysis does not detect this; CCSD may stop converging a few steps later. Inspect `INFO_RESTART/scf_check.dat`, and consider restarting from before the crossing with `reuse_guess = 0`, or a different reference. See [EOM-SF](methods/eom-sf.md#caveats). |
| `EOM-EE state n lies below the CCSD reference` | The trajectory has left the region EOM-EE can describe (bond breaking, crossing with S₀). NewtonX usually stops next with `Total energy changed more than Etot_jump`. Consider [EOM-SF](methods/eom-sf.md). |

## Problems without an error

| Symptom | Likely cause and fix |
|---|---|
| Total energy drifts or jumps by more than a few tens of meV | Loose convergence (use the tight thresholds in [Methods](methods/README.md#keywords-shared-by-all-methods)), or a time step too large near a crossing. |
| Two runs from the same initial condition hop differently | `seed = 1` in `sh.inp` draws a new random seed each run; set a fixed number. |
| Steps are slower than expected | Every coupling job also computes all gradients. See [Benchmarks](benchmarks/README.md) for cheaper choices: `nac_mode`, `thres` and `vdoth = 2`. |
| `$QCSCRATCH` fills up | Each trajectory keeps one small orbital file in `$QCSCRATCH/nxqc_<id>`; delete these after the runs. Q-Chem's own scratch folders are removed after each job. |

## See also

- [Settings reference](par-reference.md)
- [Outputs, plots and tests](outputs.md)
