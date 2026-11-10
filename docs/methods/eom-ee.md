[Home](../../README.md) / [Methods](README.md) / EOM-EE-CCSD

# EOM-EE-CCSD

> **Use it for** relaxation among excited states of a closed-shell molecule, such as S₂ → S₁.
> **Couplings:** coupling vectors from Q-Chem, or Baeck-An couplings from energies.

## Caveats

- **The ground state is not one of the states.** The CCSD ground state is the reference, and the EOM states are excited states only, so decay to S₀ cannot be simulated. For dynamics that reach the ground state, use [EOM-SF](eom-sf.md).
- **EOM-EE breaks down where the reference stops being the ground state**, as in bond breaking or near a crossing with S₀. There an EOM state can fall below the CCSD reference. The interface then warns (`EOM-EE state n lies below the CCSD reference`), and NewtonX usually stops on the energy jump. The [methaniminium example](../../examples/methaniminium_eomee) ends this way at 14.5 fs, when the C–N bond reaches 2.16 Å.
- With a closed-shell reference, `EE_STATES` gives singlets. Triplets (`EE_TRIPLETS`) are untested with the interface, and singlets and triplets cannot be mixed in one run: there is no spin–orbit coupling.

## Reference and states

| Reference | `$molecule` line | States |
|---|---|---|
| closed-shell ground state | e.g. `0 1` or `1 1` | `EE_STATES [n]`: the n lowest excited singlets |

Set `nstat` in `control.dyn` to at most n. State 1 is S₁, state 2 is S₂, and so on.

## Template

Full input: [`docs/templates/ee.qchem.inp`](../templates/ee.qchem.inp), the template of the [methaniminium example](../../examples/methaniminium_eomee). Copy it to `JOB_NAD/qchem.inp` and change the molecule. The method block is:

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

## Method-specific keywords

| Keyword | Value | Why |
|---|---|---|
| `EE_STATES` | `[n]` | Number of excited states; singlets for a closed-shell reference. |
| `EE_SINGLETS`, `EE_TRIPLETS` | not tested | Spin-specific alternatives to `EE_STATES`. Untested with the interface and not read by the initial-conditions script; use `EE_STATES`. |

The [shared keywords](README.md#keywords-shared-by-all-methods) apply too.

## Settings

| File | Setting | Suggestion |
|---|---|---|
| `qchem.par` | `nac_mode` | default `nx` |
| `sh.inp` | `vdoth` | `0`; `2` for large molecules |

## Run it

The example [`examples/methaniminium_eomee`](../../examples/methaniminium_eomee) starts CH₂NH₂⁺ on S₂ and decays to S₁, about 85 s per step on 4 cores.

## See also

- [EOM-SF](eom-sf.md), for decay to the ground state
- [Couplings](../couplings.md)
- [Settings reference](../par-reference.md)
