[Home](../README.md) / Examples

# Examples

Each example is a complete NewtonX trajectory directory: the inputs, the results, the Q-Chem output of every step, and a plot. To rerun one, copy the directory and start NewtonX in the copy:

```bash
cp -r examples/methane_cation_eomip_full ~/TRAJ_methane && cd ~/TRAJ_methane
rm -rf RESULTS INFO_RESTART plots
nohup $NX/moldyn.pl > moldyn.log 2>&1 &
```

The inputs use a fixed `seed`, so a rerun on the same Q-Chem build should follow the same trajectory closely (multithreaded Q-Chem is not bit-reproducible).

| Example | Method | What it shows | Length | Cost per step (4 cores) |
|---|---|---|---|---|
| [methane_cation_eomip_full](methane_cation_eomip_full) | EOM-IP | CH₄⁺ relaxation through its Jahn–Teller crossings, all couplings computed (`nac_mode = full`) | 50 fs | about 60 s |
| [methane_cation_eomip_carry](methane_cation_eomip_carry) | EOM-IP | the same trajectory with `nac_mode = carry` | 50 fs | about 30 s |
| [methane_cation_eomip_active](methane_cation_eomip_active) | EOM-IP | the same trajectory with `nac_mode = active` | 50 fs | about 29 s |
| [methyl_radical_eomea](methyl_radical_eomea) | EOM-EA | CH₃ radical from the CH₃⁺ reference; C–H dissociation, ending where the reference breaks down | 26 fs | about 65 s |
| [methaniminium_eomee](methaniminium_eomee) | EOM-EE | S₂ → S₁ decay of CH₂NH₂⁺, ending where EOM-EE breaks down | 14.5 fs | about 85 s |
| [ethylene_eomsf](ethylene_eomsf) | EOM-SF | ππ* ethylene; a UHF reference that switches solutions, and how `scf_check` detects it | 9 fs | about 145 s |

The three methane runs start from the same geometry, velocities and random seed, so they show what the cheaper [coupling modes](../docs/couplings.md#coupling-modes) change. All three give the same trajectory, at half the cost for `carry` and `active`; see the [comparison](../docs/benchmarks/README.md#coupling-modes).

Costs are medians measured while other jobs shared the node; they are for comparison, not absolute timings.

## What each example contains

| Path | Contents |
|---|---|
| `control.dyn`, `sh.inp`, `jiri.inp`, `geom`, `veloc`, `qchem.par`, `JOB_NAD/qchem.inp` | Inputs |
| `RESULTS/` | NewtonX results (`en.dat`, `sh.out`, `dyn.out`, …); `stop_reason.txt`, a copy of `DEBUG/runnx.error`, if the run stopped early |
| `INFO_RESTART/qchem_outputs/` | Q-Chem output of every step, gzipped |
| `plots/overview.png`, `plots/summary.json` | Energies, populations, couplings, total energy and geometry; hops and energy drift in numbers |

To plot your own trajectory the same way:

```bash
python3 tools/plot_trajectory.py ~/TRAJ_methane --title "my run" --coord "C-H:bond:1,2"
```

See [Outputs](../docs/outputs.md) for every file.
