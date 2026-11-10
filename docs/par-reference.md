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

Which coupling vectors are computed at each step, and so how many Q-Chem jobs run.

**Why it matters.** One Q-Chem job gives the couplings of one state with every other state. The interface always targets the active state first, so one job covers every pair that includes the active state. A pair of two *other* states needs an extra job targeting one of them.

For example, with 3 states and the trajectory on state 2, one job gives pairs 1–2 and 2–3. Pair 1–3 needs a second job.

| Value | Pairs with the active state | Pairs of two other states | Q-Chem jobs per step (n states) |
|---|---|---|---|
| `nx` (default) | computed when NewtonX asks for them | computed when NewtonX asks for them, otherwise zero | up to n − 1. With NewtonX's default settings it asks for every pair, so n − 1. When it asks for none, 1 gradient-only job |
| `full` | always computed | always computed | n − 1 |
| `carry` | always computed | not computed: each keeps the value from the last step it was computed (for example before a hop), with its sign kept consistent; zero until it has been computed once | 1 |
| `active` | always computed | not computed: set to zero | 1 |

- Use `nx` unless you have a reason not to: NewtonX's `jiri.inp` and `thres` settings then decide which pairs matter.
- `full`, `carry` and `active` ignore what NewtonX asks for. `carry` and `active` cost one job per step whatever n is; [compare them with `full`](benchmarks/README.md#coupling-modes) on a few trajectories before relying on them.
- `nac_mode` has no effect with `vdoth = 2` or on adiabatic steps, which need only a gradient.

What each mode does to the dynamics is explained in [Couplings](couplings.md#coupling-modes).

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
