# Changelog

All notable changes to the NewtonX–Q-Chem interface. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.0] - 2026-11-09

Refactored and improved with Claude Code (Anthropic), using the Claude Opus 5.5 model; see the AI-use note in the [README](README.md#credits-citation-and-license).

### Added

- Settings file `qchem.par` with checked keywords and defaults ([Settings reference](docs/qchem-par.md)).
- Coupling modes `nac_mode = nx | full | carry | active`. The default `nx` follows the pairs NewtonX asks for (`transmomin`).
- Coupling signs kept continuous across hops: pairs without a value at the previous step are aligned to the last sign-corrected vector in `INFO_RESTART/nac_phase_ref`. Couplings below 10⁻³ a.u. are not used as references.
- NewtonX 2.6 support. The interface keeps its coupling signs when NewtonX 2.6 runs its own `phase_correction`.
- Gradient-only steps: time-dependent Baeck-An couplings (`vdoth = 2`), `JOB_AD` templates, and adiabatic steps read from NewtonX's `typeofdyn.out`.
- Gradient reuse after a hop, without a new Q-Chem run when the gradient of the new state is known.
- `run-qchem-eom-initcond.pl` for NewtonX initial conditions and spectra.
- `scf_check`, which warns when an open-shell reference follows an excited SCF solution, and a warning when an EOM-EE state falls below the CCSD reference.
- A warning that EOM-SF coupling vectors are not documented by Q-Chem.
- NewtonX installer `nx/install.pl`, which patches `colib_perl.pm` atomically and installs a NewtonX test case.
- Regression tests that replay real Q-Chem outputs (`tests/run_tests.sh`).
- Tools: `plot_trajectory.py`, `compare_trajectories.py`, `compare_qchem_outputs.py` and `qchem_freq_to_nx.py`.
- Documentation under `docs/`, method tutorials, validation runs, and complete example trajectories.
- License GPL-3.0-or-later and `CITATION.cff`.

### Changed

- The interface reads NewtonX conventions for coupling selection, `vdoth` and hops instead of its own settings.
- The methane-cation sample was replaced by runs made with sign tracking.

### Fixed

- Coupling signs after a hop: a pair computed for the first time after a hop could have the opposite sign to its last value.

## [1.1] - 2026-08-10

### Added

- Archiving intervals for the Q-Chem outputs.

## [1.0] - 2025-12-10

First version of the interface, with a sample trajectory.

[2.0]: https://github.com/Matsika-Lab/nx-qchem-interface/compare/e0ba2d6...main
[1.1]: https://github.com/Matsika-Lab/nx-qchem-interface/compare/296e7bc...e0ba2d6
[1.0]: https://github.com/Matsika-Lab/nx-qchem-interface/commit/9043351
