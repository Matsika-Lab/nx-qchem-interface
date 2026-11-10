[Home](../../README.md) / [Methods](README.md) / EOM-EE-CCSD

# EOM-EE-CCSD

This page shows how to set up surface hopping among the excited states of a closed-shell molecule with EOM-EE-CCSD: the reference, the keywords, and the settings that matter. You need it for relaxation that stays among excited states.

## When to use it

> Use EOM-EE-CCSD for relaxation among excited states of a closed-shell molecule, such as S₂ → S₁. The ground state is not one of the states.
>
> **Couplings:** coupling vectors from Q-Chem, or Baeck-An couplings from energies.

## Keywords

| Keyword | Example value | Meaning |
|---|---|---|
| `$molecule` charge and multiplicity | `0 1` or `1 1` | The closed-shell ground state, which is the CCSD reference. |
| `EE_STATES` | `[3]` | The n lowest excited states; singlets for a closed-shell reference. One value, because symmetry is off. State 1 is S₁, state 2 is S₂, and so on. |
| `EE_SINGLETS`, `EE_TRIPLETS` | — | Spin-specific alternatives to `EE_STATES` (untested). The initial-conditions script does not read them; use `EE_STATES`. |

The [shared keywords](README.md#keywords-shared-by-all-methods) (`METHOD`, `CALC_NAC`, `SYM_IGNORE`, convergence thresholds) apply too.

## Couplings allowed

Both kinds work; see [Couplings](../couplings.md#which-methods-allow-which-couplings).

- **Coupling vectors** (`vdoth = 0`): analytic EOM-EE-CCSD couplings from Q-Chem, with `CALC_NAC 2`.
- **Baeck-An couplings** (`vdoth = 2`): NewtonX computes them from energies, and the interface runs one gradient-only job per step.

## Template

Full input: [`docs/templates/ee.qchem.inp`](../templates/ee.qchem.inp), the template of the [methaniminium example](../../examples/methaniminium_eomee), which starts CH₂NH₂⁺ on S₂ and decays to S₁. Copy it to `JOB_NAD/qchem.inp`, change the molecule, and run as in [Your first trajectory](../first-trajectory.md#7-run). The method block is:

```text
$rem
METHOD            EOM-CCSD
EE_STATES         [3]
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
| `control.dyn` | `nstat` | At most the n of `EE_STATES`. |
| `qchem.par` | [`nac_mode`](../qchem-par.md#nac_mode) | Keep the default, `nx`. |
| `sh.inp` | [`vdoth`](../qchem-par.md#related-newtonx-settings) | `0`, set explicitly (NewtonX's default is `2`); `2` for large molecules. |

## Pitfalls

- **The ground state is not one of the states.** The CCSD ground state is the reference, and the EOM states are excited states only, so decay to S₀ cannot be simulated. For dynamics that reach the ground state, use [EOM-SF](eom-sf.md).
- **EOM-EE breaks down where the reference stops being the ground state**, as in bond breaking or near a crossing with S₀. There an EOM state can fall below the CCSD reference. The interface then warns (`EOM-EE state n lies below the CCSD reference`), and NewtonX usually stops on the energy jump. The [methaniminium example](../../examples/methaniminium_eomee) ends this way at 14.5 fs, when the C–N bond reaches 2.16 Å.
- **No triplets alongside singlets.** With a closed-shell reference, `EE_STATES` gives singlets. Triplets (`EE_TRIPLETS`) are untested with the interface, and singlets and triplets cannot be mixed in one run: there is no spin–orbit coupling.

## Cost

About 85 s per step on 4 cores of a shared node for the [methaniminium example](../../examples/methaniminium_eomee) with 3 states; see [Validation](../validation.md#7-cost-per-step-of-the-examples).

## See also

- [EOM-SF](eom-sf.md): for decay to the ground state
- [Couplings](../couplings.md): coupling vectors and Baeck-An couplings
- [Settings reference](../qchem-par.md): every `qchem.par` key and its default
