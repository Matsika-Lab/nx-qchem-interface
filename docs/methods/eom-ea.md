[Home](../../README.md) / [Methods](README.md) / EOM-EA-CCSD

# EOM-EA-CCSD

This page shows how to set up surface hopping on electron-attached states with EOM-EA-CCSD: the reference to give Q-Chem, the keywords, and the settings that matter. You need it for radicals made from a closed-shell cation, and for anions.

## When to use it

> Use EOM-EA-CCSD for dynamics of electron-attached (N + 1 electron) states: radicals made from a closed-shell cation, or anions.
>
> **Couplings:** coupling vectors from Q-Chem, or Baeck-An couplings from energies.

## Keywords

| Keyword | Example value | Meaning |
|---|---|---|
| `$molecule` charge and multiplicity | `1 1` | The closed-shell molecule **before** attachment, often a cation. For the methyl radical, the reference is CH₃⁺. |
| `EA_STATES` | `[3]` | The n lowest attached states, by default attaching a β electron. One value, because symmetry is off. State 1 is the ground state of the N + 1 electron system. |
| `EA_ALPHA`, `EA_BETA` | — | Spin-specific alternatives to `EA_STATES` (untested). The initial-conditions script does not read them; use `EA_STATES`. |

The [shared keywords](README.md#keywords-shared-by-all-methods) (`METHOD`, `CALC_NAC`, `SYM_IGNORE`, convergence thresholds) apply too.

## Couplings allowed

Both kinds work; see [Couplings](../couplings.md#which-methods-allow-which-couplings).

- **Coupling vectors** (`vdoth = 0`): analytic EOM-EA-CCSD couplings from Q-Chem, with `CALC_NAC 2`.
- **Baeck-An couplings** (`vdoth = 2`): NewtonX computes them from energies, and the interface runs one gradient-only job per step.

## Template

Full input: [`docs/templates/ea.qchem.inp`](../templates/ea.qchem.inp), the template of the [methyl-radical example](../../examples/methyl_radical_eomea), which starts on the third state of CH₃. Copy it to `JOB_NAD/qchem.inp`, change the molecule, and run as in [Your first trajectory](../first-trajectory.md#7-run). The method block is:

```text
$rem
METHOD            EOM-CCSD
EA_STATES         [3]
BASIS             cc-pVDZ
CALC_NAC          2
SYM_IGNORE        TRUE
SCF_CONVERGENCE           9
CC_CONVERGENCE            9
EOM_DAVIDSON_CONVERGENCE  9
$end
```

## Settings

| File | Setting | Suggestion |
|---|---|---|
| `control.dyn` | `nstat` | At most the n of `EA_STATES`. |
| `qchem.par` | [`nac_mode`](../qchem-par.md#nac_mode) | Keep the default, `nx`. |
| `sh.inp` | [`vdoth`](../qchem-par.md#related-newtonx-settings) | `0`, set explicitly (NewtonX's default is `2`); `2` for large molecules. |

## Pitfalls

- **Wrong reference.** Give Q-Chem the molecule **before** attachment: for the methyl radical, the closed-shell cation CH₃⁺ (charge 1, multiplicity 1).
- **Unbound anion states.** For anions built from a neutral reference, states above the detachment threshold are not bound, and a basis without diffuse functions describes them poorly. Radicals from closed-shell cations avoid this.
- **Unrestricted reference.** EOM-EA analytic gradients need an unrestricted reference. Q-Chem switches to it by itself (`Setting UNRESTRICTED=TRUE`); this is expected.

## Cost

About 70 s per step on 4 cores of a shared node for the [methyl-radical example](../../examples/methyl_radical_eomea) with 3 states; see [Validation](../validation.md#7-cost-per-step-of-the-examples).

## See also

- [Couplings](../couplings.md): coupling vectors and Baeck-An couplings
- [Settings reference](../qchem-par.md): every `qchem.par` key and its default
- [Other methods](README.md): compare the four EOM flavors
