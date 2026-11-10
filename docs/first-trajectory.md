[Home](../README.md) / Your first trajectory

# Your first trajectory

This page walks through one surface-hopping trajectory from an empty folder to results. Units follow NewtonX: hartree, bohr, atomic units of velocity, and femtoseconds for time.

## 1. Make the trajectory folder

```text
TRAJ1/
├── control.dyn      dynamics settings: prog = 22, states, time step, length
├── sh.inp           surface-hopping settings
├── jiri.inp         which couplings NewtonX asks for
├── geom             initial geometry (bohr, NewtonX format)
├── veloc            initial velocities (atomic units)
├── qchem.par        interface settings (optional)
└── JOB_NAD/
    └── qchem.inp    Q-Chem template for steps with couplings
```

The quickest start is to copy an example, for instance [`examples/methane_cation_eomip_full`](../examples/methane_cation_eomip_full), and replace its files one by one. Delete the copy's `RESULTS/`, `INFO_RESTART/` and `plots/` folders, and the `nac_mode = full` line of its `qchem.par` to start from the defaults.

## 2. Set the dynamics (`control.dyn`)

```text
 &input
   nat        = 5
   nstat      = 3
   nstatdyn   = 3
   dt         = 0.25
   tmax       = 50
   prog       = 22
   thres      = 100
/
```

| Keyword | Meaning |
|---|---|
| `nat` | number of atoms |
| `nstat` | number of EOM states in the dynamics |
| `nstatdyn` | starting state; states are numbered by energy from 1 |
| `dt`, `tmax` | time step and trajectory length (fs) |
| `prog` | `22` selects Q-Chem |
| `thres` | couplings are computed only for gaps below this value (eV); `100` means always. See [Couplings](couplings.md#letting-newtonx-choose-the-pairs) |

The examples contain the other NewtonX keywords with sensible values.

## 3. Write the Q-Chem template (`JOB_NAD/qchem.inp`)

Take the template for your method from the [method tutorials](methods/README.md). Every template needs:

- the reference **charge and multiplicity** on the line right after `$molecule`. The coordinates below it are replaced at every step.
- `SYM_IGNORE TRUE`. States are addressed as `[1,n]`, which is only correct without symmetry, and it also stops Q-Chem from reorienting the molecule.
- `CALC_NAC 2`, which turns on Q-Chem's coupling vectors.
- at least `nstat` states.

Leave out `CC_STATE_TO_OPT` and `SCF_GUESS`; the interface sets both at every step.

## 4. Initial conditions (`geom`, `veloc`)

Any NewtonX initial-condition method works; to check vertical energies and intensities with Q-Chem, see [Initial conditions and spectra](initial-conditions.md). To sample from a Q-Chem frequency calculation (the examples used MP2/cc-pVDZ):

1. Run the frequency job with `MOLDEN_FORMAT TRUE`.
2. Convert it: `python3 tools/qchem_freq_to_nx.py freq.out IC`. NewtonX expects all 3N modes with the translations and rotations first, while Q-Chem prints only the vibrations; the tool adds the missing modes as zeros and writes `IC/molden.freq` and `IC/geom` (bohr).
3. In `IC`, sample with NewtonX's `initcond.pl` using its MOLDEN reader (`iprog = 5`, `nm_flag = 2`, `file_nmodes = molden.freq`); see [Initial conditions and spectra](initial-conditions.md).
4. Make the trajectory folders from the sampled points with NewtonX's `$NX/makedir.pl`, or copy one point's geometry and velocities from `final_output` into `geom` and `veloc`.

## 5. Choose the interface settings (`qchem.par`, optional)

```ini
nt = 4          # threads per Q-Chem run
```

The defaults suit most runs. See the [settings reference](par-reference.md) for every option.

## 6. Make hops reproducible (`sh.inp`)

NewtonX's default, `seed = 1`, takes a new random seed from the clock at every run. Set `seed` to any other positive number to reproduce a trajectory or to compare settings.

## 7. Run

```bash
cd TRAJ1
$NX/moldyn.pl > moldyn.log
```

`RESULTS/nx.log` starts with the interface's checks and settings:

```text
Dynamics with Q-CHEM
-----------------------------------------------------------------------
NEWTON-X/Q-CHEM EOM-CCSD interface by D. Abeygunewardane and S. Matsika,
Temple University
-----------------------------------------------------------------------
	Q-Chem: /path/to/qchem
	QCSCRATCH: /path/to/scratch
	Interface settings (qchem.par):
	   nt                   = 4
	   nac_mode             = nx
	   ...
```

Every step then reports what the interface asked Q-Chem for, followed by the state energies:

```text
run-qchem-eom.pl: nac_mode = nx; 2 Q-Chem job(s), target state(s) 3,1; couplings wanted: 1-2 1-3 2-3
State energies (a.u.):
  State 1: -39.86818875
  ...
```

`RESULTS/en.dat` has one line per step: the time, the energy of each state, the active-state energy, and the total energy.

```text
     0.000   -39.868188750   -39.832202760   -39.810985220   -39.810985220   -39.792500643
     0.250   -39.870624250   -39.832617990   -39.815694880   -39.815694880   -39.792538028
```

## 8. Look at the results

```bash
python3 /path/to/nx-qchem-interface/tools/plot_trajectory.py TRAJ1 --title "My molecule"
```

Run it from the folder that holds `TRAJ1`. The figure goes to `TRAJ1/plots/overview.png`. It draws the state energies, populations, coupling strengths and energy conservation; see [Outputs, plots and tests](outputs.md).

## Next

- [Method tutorials](methods/README.md)
- [Couplings and coupling modes](couplings.md)
- [Troubleshooting](troubleshooting.md)
