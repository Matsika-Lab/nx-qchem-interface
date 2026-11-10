[Home](../../README.md) / [Methods](README.md) / EOM-EA-CCSD

# EOM-EA-CCSD

> **Use it for** dynamics of electron-attached (N + 1 electron) states: radicals made from a closed-shell cation, or anions.
> **Couplings:** coupling vectors from Q-Chem, or Baeck-An couplings from energies.

## Caveats

- Give Q-Chem the molecule **before** attachment. For the methyl radical, the reference is the closed-shell cation CH₃⁺ (charge 1, multiplicity 1).
- For anions built from a neutral reference, states above the detachment threshold are not bound, and a basis without diffuse functions describes them poorly. Radicals from closed-shell cations avoid this.
- EOM-EA analytic gradients need an unrestricted reference. Q-Chem switches to it by itself (`Setting UNRESTRICTED=TRUE`).

## Reference and states

| Reference | `$molecule` line | States |
|---|---|---|
| closed-shell molecule, often a cation | e.g. `1 1` | `EA_STATES [n]`: the n lowest attached states, by default attaching a β electron |

Set `nstat` in `control.dyn` to at most n. State 1 is the ground state of the N + 1 electron system.

## Template

Full input: [`docs/templates/ea.qchem.inp`](../templates/ea.qchem.inp), the template of the [methyl-radical example](../../examples/methyl_radical_eomea). Copy it to `JOB_NAD/qchem.inp` and change the molecule. The method block is:

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

## Method-specific keywords

| Keyword | Value | Why |
|---|---|---|
| `EA_STATES` | `[n]` | Number of attached states; one value because symmetry is off. |
| `EA_ALPHA`, `EA_BETA` | not tested | Spin-specific alternatives to `EA_STATES`. Untested with the interface and not read by the initial-conditions script; use `EA_STATES`. |

The [shared keywords](README.md#keywords-shared-by-all-methods) apply too.

## Settings

| File | Setting | Suggestion |
|---|---|---|
| `qchem.par` | `nac_mode` | default `nx` |
| `sh.inp` | `vdoth` | `0`; `2` for large molecules |

## Run it

The example [`examples/methyl_radical_eomea`](../../examples/methyl_radical_eomea) starts on the third state of CH₃, about 65 s per step on 4 cores.

## See also

- [Couplings](../couplings.md)
- [Settings reference](../par-reference.md)
- [Other methods](README.md)
