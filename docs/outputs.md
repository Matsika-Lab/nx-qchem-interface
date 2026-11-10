[Home](../README.md) / Outputs and plots

# Outputs and plots

This page lists the files the interface writes and the tools that plot and compare trajectories. The test suite is described in [Development and testing](development.md).

## Files written by the interface

Besides NewtonX's own `RESULTS/` files (`en.dat`, `dyn.out`, `sh.out`, `tprob`, `nx.log`):

| File | Contents |
|---|---|
| `INFO_RESTART/qchem_outputs/<time>.out.gz` | The Q-Chem output of every archived step. |
| `INFO_RESTART/qchem_outputs/<time>.after_hop.out.gz` | A Q-Chem run after a hop, when the new state's gradient had to be computed. |
| `INFO_RESTART/scf_check.dat` | With [`scf_check`](qchem-par.md#scf_check) on: per step, the time, the followed and the fresh-guess SCF energies (hartree) and their difference (eV). |
| `INFO_RESTART/nac_phase_ref` | The last sign-corrected coupling of every pair. Survives restarts. |
| `TEMP/qchem.inp`, `TEMP/qchem.out` | Input and output of the latest step. |
| `TEMP/epot`, `grad`, `grad.all`, `nad_vectors` | What the interface hands NewtonX: energies, the active-state gradient, all gradients, and the couplings. |
| `TEMP/nad_vectors-2dt` | NewtonX 2.6 only: rewritten at each coupling step so that NewtonX's own sign check keeps the interface's signs; see [Coupling signs](couplings.md#newtonx-26). |
| `$QCSCRATCH/nxqc_<id>/53.0` | Orbitals carried to the next step. Safe to delete after the trajectory. |

## Plotting a trajectory

[`tools/plot_trajectory.py`](../tools/plot_trajectory.py) draws one overview figure per trajectory, and writes `summary.json` with the hops and energy drift. It shows:

- the state energies, with the active state and the hops;
- the state populations;
- the coupling strength |**v**·**d**| of every pair;
- total-energy conservation;
- any internal coordinates you name.

```bash
python3 tools/plot_trajectory.py TRAJ1 --title "Ethylene, EOM-SF-CCSD" \
    --coord "H–C=C–H twist:dihedral:3,1,2,5" --coord "C=C:bond:1,2"
```

Coordinates are `label:type:atoms`, where the type is `bond`, `angle` or `dihedral` and the atoms are numbered from 1. The figure goes to `TRAJ1/plots/overview.png`.

[`tools/compare_trajectories.py`](../tools/compare_trajectories.py) compares runs from one initial condition, for instance the three coupling modes:

```bash
python3 tools/compare_trajectories.py full=RUN_A carry=RUN_B active=RUN_C --out compare.png
```

[`tools/compare_qchem_outputs.py`](../tools/compare_qchem_outputs.py) compares the energies, gradients and couplings of Q-Chem outputs (plain or gzipped) against a reference output. The [validation](validation.md) runs use it.

[`tools/qchem_freq_to_nx.py`](../tools/qchem_freq_to_nx.py) turns a Q-Chem frequency output into NewtonX `initcond` input; see [Your first trajectory](first-trajectory.md#4-initial-conditions-geom-veloc).

These tools need Python 3 with NumPy and Matplotlib.

## See also

- [Examples](../examples/README.md): complete trajectories with their plots
- [Development and testing](development.md): the test suite
- [Troubleshooting](troubleshooting.md): error messages
