# NewtonX–Q-Chem interface

`run-qchem-eom.pl` lets [NewtonX](https://newtonx.org/) run trajectory surface hopping on Q-Chem equation-of-motion coupled-cluster (EOM-CCSD) potential energy surfaces. At every time step it runs Q-Chem and passes back state energies, gradients and nonadiabatic coupling vectors, with their signs kept continuous along the trajectory.

## Requirements

| Software | Version |
|---|---|
| NewtonX | 2.4 (build 06) or 2.6 (build 01); the interface adapts to the version by itself |
| Q-Chem | 5.4 or later, tested with 5.4.1 |
| Perl | 5.14 or later, core modules only |
| Python 3 | with NumPy, for the tests and tools; Matplotlib for the plots |
| Environment | `NX` points to NewtonX's `bin` folder, which you can write to. `qchem` is on your `PATH`, and `QCSCRATCH` is set. |

## Quick start

```bash
git clone https://github.com/Matsika-Lab/nx-qchem-interface.git
cd nx-qchem-interface
perl nx/install.pl          # registers Q-Chem as prog = 22 in NewtonX and installs the scripts
tests/run_tests.sh          # about 10 s, no Q-Chem run
```

Then run the methane-cation example:

1. Copy it, and keep only the inputs:

   ```bash
   cp -r examples/methane_cation_eomip_full ~/TRAJ_methane && cd ~/TRAJ_methane
   rm -rf RESULTS INFO_RESTART plots
   ```

2. Start NewtonX in the background:

   ```bash
   nohup $NX/moldyn.pl > moldyn.log 2>&1 &
   ```

This runs a complete 50 fs trajectory: 200 steps of about 60 s each on 4 cores, so 3–4 hours ([Validation](docs/validation.md#coupling-modes)). To set up your own molecule, follow [Your first trajectory](docs/first-trajectory.md).

## Methods

| Method | Q-Chem keyword | Couplings | Tutorial |
|---|---|---|---|
| EOM-IP-CCSD | `IP_STATES` | coupling vectors or Baeck-An | [EOM-IP](docs/methods/eom-ip.md) |
| EOM-EA-CCSD | `EA_STATES` | coupling vectors or Baeck-An | [EOM-EA](docs/methods/eom-ea.md) |
| EOM-EE-CCSD | `EE_STATES` | coupling vectors or Baeck-An | [EOM-EE](docs/methods/eom-ee.md) |
| EOM-SF-CCSD | `SF_STATES` | coupling vectors (not documented by Q-Chem; the interface warns) or Baeck-An | [EOM-SF](docs/methods/eom-sf.md) |

EOM-EE dynamics covers excited states only: the ground state is not among the states. See [Choosing an EOM method](docs/methods/README.md).

## Where to go next

| I want to… | Read |
|---|---|
| Install, update or check the installation | [Installation](docs/installation.md) |
| Set up and run a trajectory from scratch | [Your first trajectory](docs/first-trajectory.md) |
| Sample initial conditions or compute a spectrum | [Initial conditions and spectra](docs/initial-conditions.md) |
| Choose an EOM method and write its Q-Chem template | [Methods](docs/methods/README.md) |
| Look up a `qchem.par` setting | [Settings reference](docs/qchem-par.md) |
| Understand coupling vectors, Baeck-An couplings, coupling modes and signs | [Couplings](docs/couplings.md) |
| Find an output file or plot a trajectory | [Outputs and plots](docs/outputs.md) |
| Understand an error message | [Troubleshooting](docs/troubleshooting.md) |
| See how fast and how accurate it is, and how it was tested | [Validation](docs/validation.md) |
| Run or add tests | [Development and testing](docs/development.md) |
| Follow the documentation style | [Documentation style](docs/STYLE.md) |
| See what changed between versions | [Changelog](CHANGELOG.md) |

## Examples

[`examples/`](examples/README.md) holds complete trajectories, one or more per method, with inputs, results, every Q-Chem output and a plot.

## Credits, citation and license

- **Authors:** Dakshitha Abeygunewardane and Spiridoula Matsika, Matsika Lab, Department of Chemistry, Temple University. The interface follows the NewtonX third-party-program interface template by Mario Barbatti (2021).
- **AI use:** the 2026-11-09 revision (version 2.0) was refactored and improved with Claude Code (Anthropic), using the Claude Opus 5.5 model.
  - **What it covered:**
    - the coupling-sign handling and the interface rework (`qchem.par`, coupling modes, gradient-only steps, NewtonX 2.6 support);
    - `run-qchem-eom-initcond.pl`;
    - the NewtonX installer;
    - the regression tests;
    - the plotting tools;
    - the validation runs and the example trajectories;
    - the method tutorials and the documentation.
  - **Decisions:** the authors made the design decisions.
  - **Commits:** the commits of this revision carry `Co-Authored-By: Claude` lines.
- **Citation:** see [`CITATION.cff`](CITATION.cff) (GitHub's "Cite this repository" button reads it). Please also cite NewtonX and Q-Chem. EOM-CC couplings in Q-Chem follow Tajti and Szalay, *J. Chem. Phys.* 131, 124104 (2009), and Faraji, Matsika and Krylov, *J. Chem. Phys.* 148, 044103 (2018).
- **License:** GPL-3.0-or-later, see [`LICENSE`](LICENSE).
