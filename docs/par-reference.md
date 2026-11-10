[Home](../README.md) / Settings reference

# Settings reference (`qchem.par`)

`qchem.par` holds the interface settings of one trajectory. It is optional: every setting has a default.

- Put it in the trajectory folder; NewtonX copies it into `TEMP/` at every step, and checks it when the run starts.
- One `keyword = value` per line; `#` starts a comment.
- A misspelled keyword stops the run with `Unknown keyword`, so a typo never silently falls back to a default.
- An annotated copy with every keyword is in [`qchem.par.example`](../qchem.par.example).

```ini
nt = 8
nac_mode = full
```

## Settings

| Keyword | Values | Default | Meaning |
|---|---|---|---|
| `nt` | integer ≥ 1 | `4` | Threads for each Q-Chem run (`qchem -nt`). |
| `nac_mode` | `nx`, `full`, `carry`, `active` | `nx` | Which coupling vectors are computed; see [below](#nac_mode). |
| `reuse_guess` | `1`, `0` | `1` | Start each SCF from the previous step's orbitals. Only the orbital file (`53.0`) is kept, in `$QCSCRATCH/nxqc_<id>`. Cuts SCF iterations, for example from 11 to 2 for methane. |
| `archive` | `1`, `0` | `1` | Keep each step's Q-Chem output in `INFO_RESTART/qchem_outputs/`. |
| `archive_interval` | integer ≥ 1 | `1` | Archive every n-th step. |
| `archive_gzip` | `1`, `0` | `1` | Compress archived outputs (`<time>.out.gz`). |
| `print_extracted` | `1`, `0` | `1` | Print the Q-Chem jobs of each step, the energies, the active-state gradient and the couplings in `RESULTS/nx.log`. |
| `phase_warn` | number between 0 and 1 | `0.3` | Warn when a coupling has to be aligned to a stored vector it barely overlaps (\|cos θ\| below this value). See [Couplings](couplings.md#coupling-signs). |
| `stop_on_unconverged` | `1`, `0` | `1` | Stop the trajectory when Q-Chem reports a convergence failure. `0` prints a warning and continues. |
| `scf_check` | `auto`, `1`, `0` | `auto` | With `reuse_guess = 1`, run one extra SCF per step from a fresh guess and warn when it finds a lower solution than the one being followed; see [Troubleshooting](troubleshooting.md#warnings). `auto` turns it on for open-shell (multiplicity > 1) references, such as the triplet reference of EOM-SF. Results go to `INFO_RESTART/scf_check.dat`. |

## `nac_mode`

Q-Chem computes, in one job, the couplings between the targeted state and every other state. `nac_mode` decides how many jobs run per step, and what happens to couplings between two states that are not the active state.

| Value | Q-Chem jobs per step (n states) | Couplings between two inactive states |
|---|---|---|
| `nx` | the fewest that give the pairs NewtonX asks for (n − 1 with NewtonX's defaults; one gradient-only job when NewtonX asks for none) | computed when NewtonX asks for them, zero otherwise |
| `full` | n − 1 | computed every step |
| `carry` | 1 | last computed value, sign-aligned |
| `active` | 1 | zero |

`full`, `carry` and `active` override NewtonX's own coupling selection. `nac_mode` has no effect with `vdoth = 2` or on adiabatic steps, which need only a gradient. What each mode does to the dynamics is explained in [Couplings](couplings.md#coupling-modes).

## Related NewtonX settings

These live in NewtonX's own input files but change what the interface does.

| File | Keyword | Effect on the interface |
|---|---|---|
| `sh.inp` | `vdoth` | `0`: coupling vectors from Q-Chem (needs `CALC_NAC 2`). `2`: NewtonX computes Baeck-An couplings from energies, and the interface runs one gradient-only job. Other values are refused. |
| `sh.inp` | `seed` | `1` means a random seed from the clock. Use another number for reproducible hops. |
| `jiri.inp` | `kross`, `cascade`, `current`, `never_state`, `include_pair` | Which pairs NewtonX asks for when `nac_mode = nx`. |
| `control.dyn` | `thres` | Pairs are asked for only when their gap is below this value (eV). |

## See also

- [Couplings](couplings.md)
- [Benchmarks](benchmarks/README.md): what each choice costs
