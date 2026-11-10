[Home](../README.md) / Settings reference (`qchem.par`)

# Settings reference (`qchem.par`)

`qchem.par` holds the interface settings of one trajectory: threads, which couplings Q-Chem computes, orbital reuse, output archiving and checks. The file is optional, and every setting has a default. You need this page when a default does not suit your run.

## Example file

```ini
# qchem.par in the trajectory folder
nt = 8
nac_mode = full
```

An annotated copy with every key and its default is in [`qchem.par.example`](../qchem.par.example).

## Format

- **Location.** Put `qchem.par` in the trajectory folder. NewtonX copies it into `TEMP/` when the run starts. A copy in `JOB_NAD/` is read when there is none in `TEMP/`.
- **Syntax.** One `key = value` per line. `#` starts a comment, and blank lines are ignored.
- **Case and spaces.** Keys and values are read in lowercase, so `NAC_MODE = Full` works. A value is a single word without spaces.
- **Unknown keys stop the run.** NewtonX checks the keys at start-up and stops with `Unknown keyword`, so a typo never falls back to a default.
- **Checked values.** `nac_mode`, `scf_check`, `nt` and `archive_interval` are checked at the first step, and a wrong value stops the run (see [Troubleshooting](troubleshooting.md#errors-in-debugrunnxerror)). The on/off keys and `phase_warn` are not checked: for an on/off key, `0` means off and any other value means on.
- **Initial conditions.** `run-qchem-eom-initcond.pl` reads only `nt`, from `qchem.par` in the initial-conditions folder, and ignores the other keys.

## Summary

<a id="settings"></a>

| Key | Default | Allowed values | Effect |
|---|---|---|---|
| [`nt`](#nt) | `4` | integer ≥ 1 | Threads for each Q-Chem run (`qchem -nt`) |
| [`nac_mode`](#nac_mode) | `nx` | `nx`, `full`, `carry`, `active` | Which coupling vectors are computed, and so how many Q-Chem jobs run per step |
| [`reuse_guess`](#reuse_guess) | `1` | `1`, `0` | Start each SCF from the previous step's orbitals |
| [`archive`](#archive) | `1` | `1`, `0` | Keep each step's Q-Chem output in `INFO_RESTART/qchem_outputs/` |
| [`archive_interval`](#archive_interval) | `1` | integer ≥ 1 | Archive every n-th step |
| [`archive_gzip`](#archive_gzip) | `1` | `1`, `0` | Compress archived outputs |
| [`print_extracted`](#print_extracted) | `1` | `1`, `0` | Print jobs, energies, gradient and couplings of each step in `RESULTS/nx.log` |
| [`phase_warn`](#phase_warn) | `0.3` | number from 0 to 1 | Warn when a coupling barely overlaps its stored reference |
| [`stop_on_unconverged`](#stop_on_unconverged) | `1` | `1`, `0` | Stop the trajectory when Q-Chem reports a convergence failure |
| [`scf_check`](#scf_check) | `auto` | `auto`, `1`, `0` | Compare the followed SCF solution with a fresh-guess SCF at each step |

## Keys

### `nt`

Number of threads for each Q-Chem run, passed as `qchem -nt`. It also sets the threads of the initial-conditions runs.

Change it to match the cores your job script reserves for one trajectory. When you run several trajectories on one node, keep the sum of their `nt` at or below the free cores.

```ini
nt = 8
```

### `nac_mode`

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
- `full`, `carry` and `active` ignore what NewtonX asks for. `carry` and `active` cost one job per step whatever n is; [compare them with `full`](validation.md#coupling-modes) on a few trajectories before relying on them.
- `nac_mode` has no effect with `vdoth = 2` or on adiabatic steps, which need only a gradient.

What each mode does to the dynamics is explained in [Couplings](couplings.md#coupling-modes).

```ini
nac_mode = carry
```

### `reuse_guess`

With `1`, each SCF starts from the orbitals of the previous step. Q-Chem runs with `-save`, and the interface keeps only the orbital file (`53.0`) in `$QCSCRATCH/nxqc_<id>`, one folder per trajectory. This cuts the SCF cycles, for example from 11 to 2 for the methane cation ([Validation](validation.md#3-interface-features)). With `0`, every SCF starts from Q-Chem's default guess.

Set it to `0` when the SCF follows an unwanted solution from step to step, for example after a `scf_check` warning. [`scf_check`](#scf_check) runs only when `reuse_guess = 1`.

```ini
reuse_guess = 0
```

### `archive`

With `1`, the Q-Chem output of each step is kept in `INFO_RESTART/qchem_outputs/`, named after the simulation time in fs (`<time>.out`, or `<time>.out.gz` with [`archive_gzip`](#archive_gzip)). A second run at the same geometry after a hop is kept as `<time>.after_hop.out`.

Set it to `0` for long runs or many trajectories when you do not need the outputs, to save disk space.

```ini
archive = 0
```

### `archive_interval`

Archive only the steps whose step number is a multiple of this value. It has an effect only with `archive = 1`.

Raise it to keep a sample of the outputs of a long trajectory.

```ini
archive_interval = 10
```

### `archive_gzip`

With `1`, archived outputs are compressed with gzip (`<time>.out.gz`). With `0`, they are plain copies.

Set it to `0` if you want to read the outputs without `zcat` or `zless`.

```ini
archive_gzip = 0
```

### `print_extracted`

With `1`, the interface prints in `RESULTS/nx.log` at each step: the Q-Chem jobs it runs, the state energies, the gradient of the active state, and the couplings, each marked as computed, carried or not computed.

Set it to `0` to keep `nx.log` short in long runs. Warnings are printed either way.

```ini
print_extracted = 0
```

### `phase_warn`

The interface aligns the sign of each coupling vector with a stored reference (see [Couplings](couplings.md#coupling-signs)). It warns when the overlap |cos θ| between the two is below this value, because the sign is then uncertain. The value is not checked; `0` turns the warning off.

Raise it to be warned about more alignments, or lower it if frequent warnings near an intersection are expected for your system.

```ini
phase_warn = 0.2
```

### `stop_on_unconverged`

With `1`, the trajectory stops when a Q-Chem job reports a convergence failure: a line containing `did not converge`, `failed to converge` or `not converged`, in any case. With `0`, the interface prints a warning in `RESULTS/nx.log` and uses the results anyway.

Keep `1` for production. Set `0` only to get past a single difficult step, and check the energies of that step afterwards.

```ini
stop_on_unconverged = 0
```

### `scf_check`

With orbital reuse ([`reuse_guess = 1`](#reuse_guess)), the SCF follows its solution from step to step. For an open-shell (UHF) reference, two SCF solutions can cross, and the trajectory can end up on the higher one; stability analysis does not detect this. With `scf_check` on, the interface runs one extra Hartree–Fock SCF per step from a fresh guess and warns when it finds a lower solution than the one followed. Each step adds a line to `INFO_RESTART/scf_check.dat`: time, followed energy, fresh-guess energy (hartree) and their difference (eV).

| Value | Effect |
|---|---|
| `auto` | On when the template's multiplicity is above 1, such as the triplet reference of EOM-SF |
| `1` | Always on |
| `0` | Off |

Set `0` to save the extra SCF for an open-shell reference you have already checked, or `1` to check a closed-shell reference too. The warning is explained in [Troubleshooting](troubleshooting.md#warnings).

```ini
scf_check = 1
```

## Related NewtonX settings

These live in NewtonX's own input files but change what the interface does.

| File | Keyword | Effect on the interface |
|---|---|---|
| `sh.inp` | `vdoth` | NewtonX's default is `2` when `sh.inp` has no `vdoth`. `0`: coupling vectors from Q-Chem (needs `CALC_NAC 2`). `2`: NewtonX computes Baeck-An couplings from energies, and the interface runs one gradient-only job. Other values are refused. |
| `sh.inp` | `seed` | `1` means a random seed from the clock. Use another number for reproducible hops. |
| `jiri.inp` | `kross`, `cascade`, `current`, `never_state`, `include_pair` | Which pairs NewtonX asks for when `nac_mode = nx`. |
| `control.dyn` | `thres` | Pairs are asked for only when their gap is below this value (eV). |

## See also

- [Couplings](couplings.md): coupling vectors, Baeck-An couplings and signs
- [Validation](validation.md): what each choice costs
- [Troubleshooting](troubleshooting.md): messages about `qchem.par`
