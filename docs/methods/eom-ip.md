[Home](../../README.md) / [Methods](README.md) / EOM-IP-CCSD

# EOM-IP-CCSD

> **Use it for** dynamics of a cation formed by ionization: the states are the ionized (N − 1 electron) states of the molecule you give Q-Chem.
> **Couplings:** coupling vectors from Q-Chem, or Baeck-An couplings from energies.

## Caveats

- Give Q-Chem the molecule **before** ionization. For the methane cation, the reference is neutral CH₄ (charge 0, multiplicity 1); a cation reference would give dication states.
- EOM-IP analytic gradients need an unrestricted reference. Q-Chem switches to it by itself and says so in the output (`Setting UNRESTRICTED=TRUE`).

## Reference and states

| Reference | `$molecule` line | States |
|---|---|---|
| neutral closed-shell molecule | `0 1` | `IP_STATES [n]`: the n lowest ionized states, by default removing a β electron |

Set `nstat` in `control.dyn` to at most n. State 1 is the cation ground state.

## Template

Full input: [`docs/templates/ip.qchem.inp`](../templates/ip.qchem.inp), the template of the [methane-cation example](../../examples/methane_cation_eomip_full). Copy it to `JOB_NAD/qchem.inp` and change the molecule. The method block is:

```text
$rem
METHOD            EOM-CCSD
IP_STATES         [3]
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
| `IP_STATES` | `[n]` | Number of ionized states; one value because symmetry is off. |
| `EOM_IP_ALPHA`, `EOM_IP_BETA` | not tested | Spin-specific alternatives to `IP_STATES`. Untested with the interface and not read by the initial-conditions script; use `IP_STATES`. |

The [shared keywords](README.md#keywords-shared-by-all-methods) apply too.

## Settings

| File | Setting | Suggestion |
|---|---|---|
| `qchem.par` | `nac_mode` | default `nx`. Ionized states of small molecules are often close together, and all pairs matter. |
| `sh.inp` | `vdoth` | `0`. Use `2` for large molecules, where each coupling job takes hours. |

## Run it

The example [`examples/methane_cation_eomip_full`](../../examples/methane_cation_eomip_full) starts on the third CH₄⁺ state, about 42 s per step on 4 cores. Large molecules cost far more: one step of 5-fluorouracil⁺ (12 atoms, cc-pVDZ) takes hours.

## See also

- [Couplings](../couplings.md)
- [Settings reference](../par-reference.md)
- [Other methods](README.md)
