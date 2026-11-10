[Home](../README.md) / Troubleshooting

# Troubleshooting

This page lists the messages of the interface and of NewtonX, what causes them and what to do. Search it for the part of the message that does not change. Where a message appears depends on who prints it:

- **Start-up checks.** Before the first step, NewtonX checks the environment, the templates and the `qchem.par` keys with the code that `nx/install.pl` adds to it. A failed check prints `<ERROR>` and the reason in the terminal (the standard output of `moldyn.pl` or `initcond.pl`); for dynamics it also goes to `RESULTS/nx.log`.
- **Warnings and per-step reports.** These start with `run-qchem-eom.pl:` and appear in `RESULTS/nx.log`.
- **Errors that stop a step.** These appear in `DEBUG/runnx.error`; `nx.log` only points there with `See also error messages in DEBUG/runnx.error`. NewtonX then copies `TEMP/` to `DEBUG/TEMP/`, so the last Q-Chem input and output of the failed step are in `DEBUG/TEMP/qchem.inp` and `DEBUG/TEMP/qchem.out`.

Messages from NewtonX itself are quoted from NewtonX 2.4 (build 06).

## Start-up messages in the terminal

| Message contains | Cause | What to do |
|---|---|---|
| `qchem is not in your PATH` | Q-Chem is not loaded in the shell that starts NewtonX. | Load Q-Chem in the shell or job script that starts NewtonX. |
| `QCSCRATCH is not defined` | The `QCSCRATCH` environment variable is not set. | Set `QCSCRATCH` in the shell or job script that starts NewtonX. |
| `Cannot find a Q-Chem template` | Dynamics: neither `JOB_NAD/qchem.inp` nor `JOB_AD/qchem.inp` exists. | Put the template in `JOB_NAD/qchem.inp` (and `JOB_AD/qchem.inp` for gradient-only steps). |
| `Initial conditions with Q-Chem need the template` | Initial conditions: `JOB_AD/qchem.inp` is missing or empty. | Put the template in `JOB_AD/qchem.inp`. |
| `must contain 'SYM_IGNORE TRUE'` | The template does not switch off symmetry, but the interface addresses states as `[1,n]`, which assumes a single irreducible representation. | Add `SYM_IGNORE TRUE` to the `$rem` section of the template. See [Methods](methods/README.md#keywords-shared-by-all-methods). |
| `must contain 'CALC_NAC 2'` | `JOB_NAD/qchem.inp` has no `CALC_NAC`, but `vdoth = 0` asks Q-Chem for coupling vectors. | Add `CALC_NAC 2` to `JOB_NAD/qchem.inp`, or set `vdoth = 2` for couplings from energies. See [Couplings](couplings.md). |
| `is not supported with Q-Chem EOM-CC` | `vdoth` in `sh.inp` is neither `0` nor `2`. Q-Chem EOM-CC gives coupling vectors but no wavefunction overlaps. | Use `vdoth = 0` (coupling vectors) or `vdoth = 2` (Baeck-An) in `sh.inp`. |
| `Unknown keyword` | `qchem.par` contains a key the interface does not know, usually a typo. | Fix that line of `qchem.par`; see the [Settings reference](qchem-par.md#summary). |
| `WARNING: EOM-SF coupling vectors are not documented` | The template uses `SF_STATES` with `vdoth = 0`. The Q-Chem manual lists EOM-CC couplings for EE, IP and EA only. | See [EOM-SF](methods/eom-sf.md#caveats). Check the couplings before production use, or use `vdoth = 2`. |
| `is dying now during` | Initial conditions: `run-qchem-eom-initcond.pl` stopped with an error. | Read the reason in `DEBUG/runnx.error`; see [Initial conditions](#errors-during-initial-conditions). |

## Warnings and reports in `RESULTS/nx.log`

<a id="warnings"></a>

| Message contains | Cause | What to do |
|---|---|---|
| `WARNING: EOM-SF coupling vectors are computed by Q-Chem but are not documented` | Printed at the first step for an EOM-SF template with coupling vectors. The Q-Chem manual lists EOM-CC couplings for EE, IP and EA only. | See [EOM-SF](methods/eom-sf.md#caveats). |
| `is nearly orthogonal to its stored reference` | A coupling vector was aligned to a stored reference it barely overlaps (\|cos θ\| below [`phase_warn`](qchem-par.md#phase_warn)), so its sign is uncertain. | Occasional warnings are normal near intersections. Frequent ones suggest `nac_mode = full`. See [Couplings](couplings.md#coupling-signs). |
| `WARNING: Q-Chem job` | Q-Chem reported a convergence failure in that job; the rest of the line quotes it. | With `stop_on_unconverged = 0` the run continues; otherwise it stops next with `Stopping on a Q-Chem convergence failure`. |
| `the SCF reference followed from the previous step is` | [`scf_check`](qchem-par.md#scf_check) found a lower SCF solution from a fresh guess. Two SCF solutions of an open-shell (UHF) reference have crossed, and the trajectory follows the higher one. Stability analysis does not detect this; CCSD may stop converging a few steps later. | Inspect `INFO_RESTART/scf_check.dat`. Consider restarting from before the crossing with `reuse_guess = 0`, or a different reference. See [EOM-SF](methods/eom-sf.md#caveats). |
| `lies below the CCSD reference` | An EOM-EE state has a negative excitation energy: the reference is no longer the ground state (bond breaking, crossing with S₀), and EOM-EE cannot describe this region. | NewtonX usually stops next with `Total energy changed more than Etot_jump` in `DEBUG/runnx.error`. Consider [EOM-SF](methods/eom-sf.md). |
| `Q-Chem returned a non-zero exit code` | Q-Chem stopped with an error. When the output gives a reason, the next line `Q-Chem reports:` quotes it. | `CCSD iterations did not converge` usually means the threshold is too tight: try `CC_CONVERGENCE 8`. For memory errors, raise `MEM_TOTAL` and `CC_MEMORY`. The run then stops with `Q-Chem failed`. |
| `See also error messages in DEBUG/runnx.error` | Printed by NewtonX when a step fails. | Read the last lines of `DEBUG/runnx.error` and look them up [below](#errors-in-debugrunnxerror). |

## Errors in `DEBUG/runnx.error`

| Message contains | Cause | What to do |
|---|---|---|
| `Q-Chem failed` | Q-Chem returned a non-zero exit code; `nx.log` has the details. | See `Q-Chem returned a non-zero exit code` [above](#warnings), and `DEBUG/TEMP/qchem.out`. |
| `Q-Chem template` … `not found` | The template for this step is missing from `TEMP/`. | Put the template in `JOB_NAD/qchem.inp` (and `JOB_AD/qchem.inp` for gradient-only steps). |
| `No charge/multiplicity line after` | The line after `$molecule` in the template is not two integers. | Put the reference charge and multiplicity on the line right after `$molecule`. |
| `Cannot read line in` | A line of `qchem.par` is not `key = value`, or the value contains spaces. | Fix that line; see the [Settings reference](qchem-par.md#format). |
| `nac_mode must be nx, full, carry or active` | Wrong value of `nac_mode` in `qchem.par`. | Use one of these four values; see [`nac_mode`](qchem-par.md#nac_mode). |
| `scf_check must be auto, 0 or 1` | Wrong value of `scf_check` in `qchem.par`. | Use one of these three values; see [`scf_check`](qchem-par.md#scf_check). |
| `must be a positive integer` | `nt` or `archive_interval` in `qchem.par` is not an integer ≥ 1. | Fix the value; see the [Settings reference](qchem-par.md#summary). |
| `is not supported: Q-Chem EOM-CC provides coupling vectors` | `vdoth` in `sh.inp` is neither `0` nor `2`. | Use `vdoth = 0` (coupling vectors) or `vdoth = 2` (Baeck-An) in `sh.inp`. |
| `geom has` … `atoms, control.d says` | `nat` in `control.dyn` does not match the number of atoms in `geom`. | Make `nat` equal to the number of atoms. |
| `Expected` … `Q-Chem job(s) in` | One job of a multi-job step did not run. | Check `DEBUG/TEMP/qchem.out` for the job that stopped. |
| `did not finish normally` | A Q-Chem job (`CC_STATE_TO_OPT [1,k]`) has no normal end in the output. Common causes are memory and scratch space. | Open `DEBUG/TEMP/qchem.out` for Q-Chem's error. |
| `Stopping on a Q-Chem convergence failure` | A Q-Chem job reported a convergence failure, and `stop_on_unconverged = 1`. | Look at that step's output. Tighter thresholds, more iterations or a smaller time step usually help. `stop_on_unconverged = 0` continues anyway, at your own risk. |
| `Expected at least` … `EOM states in` | The template asks for fewer states than `nstat`. | Ask for at least `nstat` states in the template. |
| `No gradient found for the active state` | Q-Chem did not print the gradient of the active state. | Check that step's output in `DEBUG/TEMP/qchem.out`. |
| `Coupling` … `missing in` | Q-Chem did not print a coupling it should have. | Check the output for a failed response calculation. |
| `Hopping probability is larger than one` | NewtonX: the trajectory is close to a conical intersection. | Use a smaller `dt` in `control.dyn` or more substeps (`ms` in `sh.inp`). |
| `/usr/bin/env: 'perl\r'` | Printed by the shell, not by the interface: the script has Windows line endings, usually after a download through Windows. | Convert it with `sed -i 's/\r$//' run-qchem-eom.pl run-qchem-eom-initcond.pl`, then run `perl nx/install.pl` again. |

## Errors during initial conditions

These appear in `DEBUG/runnx.error` of the initial-conditions folder.

| Message contains | Cause | What to do |
|---|---|---|
| `not found (initial conditions use JOB_AD/qchem.inp)` | `JOB_AD/qchem.inp` is missing or empty. | Put the template in `JOB_AD/qchem.inp`. |
| `has no IP_STATES, EA_STATES, EE_STATES or SF_STATES` | Initial conditions need one of these keywords; spin-specific keywords such as `EE_SINGLETS` are not read. | Use one of the four keywords in `JOB_AD/qchem.inp`. |
| `must contain SYM_IGNORE TRUE` | The template does not switch off symmetry. | Add `SYM_IGNORE TRUE` to the `$rem` section of `JOB_AD/qchem.inp`. |
| `No charge/multiplicity line after` | The line after `$molecule` in the template is not two integers. | Put the reference charge and multiplicity on the line right after `$molecule`. |
| `nfs =` … `_STATES, but` | The template asks for fewer states than `nfs` needs. | Ask for `nfs − 1` states (EE, IP, EA) or `nfs` (SF) in `JOB_AD/qchem.inp`. |
| `only transitions from state 1 are supported` | `nis` in `initqp_input` is not `1`. | Set `nis = 1` in `initqp_input`. |
| `(initial conditions for multiple states with orbitals)` | `ics_flg = y` in `initqp_input`, which the interface does not support. | Set `ics_flg = n` in `initqp_input`. |

## Problems without a message

| Symptom | Cause | What to do |
|---|---|---|
| Total energy drifts or jumps by more than a few tens of meV | Loose convergence, or a time step too large near a crossing. | Use the tight thresholds in [Methods](methods/README.md#keywords-shared-by-all-methods), or a smaller `dt`. |
| Two runs from the same initial condition hop differently | `seed = 1` in `sh.inp` draws a different random seed each run. | Set `seed` to any number other than `1`. |
| Steps are slower than expected | Every coupling job also computes all gradients. | See [Validation](validation.md) for cheaper choices: `nac_mode`, `thres` and `vdoth = 2`. |
| `$QCSCRATCH` fills up | Each trajectory keeps one small orbital file in `$QCSCRATCH/nxqc_<id>`. Q-Chem's own scratch folders are removed after each job. | Delete the `nxqc_<id>` folders after the runs. |

## See also

- [Settings reference (`qchem.par`)](qchem-par.md): every key, default and allowed value
- [Couplings](couplings.md): coupling signs and coupling modes
- [Outputs and plots](outputs.md): where each file goes
