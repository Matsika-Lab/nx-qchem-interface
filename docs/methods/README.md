[Home](../../README.md) / Methods

# Choosing an EOM method

Each EOM-CCSD flavour describes a different set of states. Pick the one whose states are the ones your dynamics visits, then follow its tutorial.

| Method | Reference you give Q-Chem | States in the dynamics | Typical use | Tutorial | Template |
|---|---|---|---|---|---|
| EOM-IP-CCSD | the molecule before ionization (N electrons) | ionized states (N − 1 electrons), lowest first | cation dynamics after photoionization | [EOM-IP](eom-ip.md) | [`ip.qchem.inp`](../templates/ip.qchem.inp) |
| EOM-EA-CCSD | the molecule before electron attachment, often a closed-shell cation | electron-attached states (N + 1 electrons) | radicals and anions | [EOM-EA](eom-ea.md) | [`ea.qchem.inp`](../templates/ea.qchem.inp) |
| EOM-EE-CCSD | the closed-shell ground state | excited states only | relaxation among excited states | [EOM-EE](eom-ee.md) | [`ee.qchem.inp`](../templates/ee.qchem.inp) |
| EOM-SF-CCSD | a high-spin triplet | ground and low singlets, plus the Ms = 0 triplet | decay to the ground state, bond twisting and breaking | [EOM-SF](eom-sf.md) | [`sf.qchem.inp`](../templates/sf.qchem.inp) |

Every template is the input of a complete [example trajectory](../../examples/README.md).

## Keywords shared by all methods

| Keyword | Value | Why |
|---|---|---|
| `METHOD` | `EOM-CCSD` | The EOM-CCSD family; the state keyword picks the flavour. |
| `CALC_NAC` | `2` | Q-Chem's coupling vectors (Szalay's method). Needed for `vdoth = 0`; harmless otherwise, because the interface removes it for gradient-only jobs. |
| `SYM_IGNORE` | `TRUE` | Required. States are addressed as `[1,n]`, and the molecule must not be reoriented. |
| `SCF_CONVERGENCE`, `CC_CONVERGENCE`, `EOM_DAVIDSON_CONVERGENCE` | `9`, `9`, `9` | Tight convergence for clean gradients and couplings, as in Q-Chem's own coupling example. Costs about 27% more than the defaults; see [Benchmarks](../benchmarks/README.md). |
| `CC_STATE_TO_OPT`, `SCF_GUESS` | — | Do not set: the interface writes them at every step. |

**If CCSD does not converge** at `CC_CONVERGENCE 9` (the amplitudes stall near 10⁻⁹, which happened for the triplet reference of ethylene), use `8`.

## See also

- [Couplings](../couplings.md): which methods give coupling vectors
- [Your first trajectory](../first-trajectory.md)
