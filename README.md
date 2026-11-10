# NewtonX–Q-Chem interface for EOM-CCSD surface hopping

`run-qchem-eom.pl` lets [NewtonX](https://newtonx.org/) 2.x run trajectory surface hopping on Q-Chem equation-of-motion coupled-cluster (EOM-CCSD) potential energy surfaces. At every time step it runs Q-Chem and passes back state energies, gradients and nonadiabatic coupling vectors, with their signs kept continuous along the trajectory.

**Methods:** EOM-IP-CCSD, EOM-EA-CCSD, EOM-EE-CCSD and EOM-SF-CCSD. **Tested with** NewtonX 2.4 and Q-Chem 5.4.1 (November 2026).

## Quick start

You need NewtonX 2.x (`$NX` set to its `bin` folder), Q-Chem (`qchem` on `PATH`, `$QCSCRATCH` set) and write access to `$NX`; see [Installation](docs/installation.md).

```bash
git clone https://github.com/Matsika-Lab/nx-qchem-interface
cd nx-qchem-interface
perl nx/install.pl          # registers Q-Chem as prog = 22 in NewtonX and installs the script
tests/run_tests.sh          # about 10 s, no Q-Chem run
cp -r examples/methane_cation_eomip_full ~/TRAJ_methane && cd ~/TRAJ_methane
rm -rf RESULTS INFO_RESTART plots   # keep only the inputs
nohup $NX/moldyn.pl > moldyn.log 2>&1 &
```

The last line starts a complete 50 fs methane-cation trajectory in the background: 200 steps of about 60 s each on 4 cores, so 3–4 hours. To set up your own system, follow [Your first trajectory](docs/first-trajectory.md).

## Where to go next

| I want to… | Read |
|---|---|
| Install, update or check the installation | [Installation](docs/installation.md) |
| Set up and run a trajectory from scratch | [Your first trajectory](docs/first-trajectory.md) |
| Sample initial conditions or compute a spectrum | [Initial conditions and spectra](docs/initial-conditions.md) |
| Choose an EOM method and write its Q-Chem template | [Methods](docs/methods/README.md) |
| Look up a `qchem.par` setting | [Settings reference](docs/par-reference.md) |
| Understand couplings, Baeck-An couplings and coupling modes | [Couplings](docs/couplings.md) |
| Find an output file, plot a trajectory or run the tests | [Outputs, plots and tests](docs/outputs.md) |
| Understand an error message | [Troubleshooting](docs/troubleshooting.md) |
| Make steps cheaper, or see what each Q-Chem option costs | [Benchmarks](docs/benchmarks/README.md) |
| See complete trajectories with plots | [Examples](examples/README.md) |

## Supported methods

| Method | Q-Chem keyword | Ground state among the states? | Couplings from Q-Chem | Tutorial |
|---|---|---|---|---|
| EOM-IP-CCSD | `IP_STATES` | yes (cation ground state) | yes | [EOM-IP](docs/methods/eom-ip.md) |
| EOM-EA-CCSD | `EA_STATES` | yes (electron-attached ground state) | yes | [EOM-EA](docs/methods/eom-ea.md) |
| EOM-EE-CCSD | `EE_STATES` | no (excited states only) | yes | [EOM-EE](docs/methods/eom-ee.md) |
| EOM-SF-CCSD | `SF_STATES` | yes | computed but not documented by Q-Chem; the interface warns | [EOM-SF](docs/methods/eom-sf.md) |

Every method can also run with couplings computed by NewtonX from the energies (time-dependent Baeck-An, `vdoth = 2`); see [Couplings](docs/couplings.md).

## Credits, citation and license

**Authors:** Dakshitha Abeygunewardane and Spiridoula Matsika, Matsika Lab, Temple University, USA. To cite the interface, use [`CITATION.cff`](CITATION.cff) (GitHub's "Cite this repository" button reads it). It is free software under the GNU General Public License, version 3 or later (`GPL-3.0-or-later`; [`LICENSE`](LICENSE)).

**AI assistance.** The November 2026 revision was refactored and improved with Claude Code using Claude Opus 5.5 (Anthropic). This covers the coupling-sign handling, the interface rework, the tests, the installer, the plotting tools, the benchmarks, the example trajectories and this documentation. Commits made with its help carry a `Co-Authored-By: Claude` line in the git history.

The interface follows the structure of the NewtonX third-party-program (TPP) interface template by Mario Barbatti (2021). EOM-CC couplings in Q-Chem follow Tajti and Szalay, *J. Chem. Phys.* 131, 124104 (2009), and Faraji, Matsika and Krylov, *J. Chem. Phys.* 148, 044103 (2018).
