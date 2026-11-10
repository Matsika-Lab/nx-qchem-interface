[Home](../../README.md) / [Methods](README.md) / EOM-IP-CCSD

# EOM-IP-CCSD

This page shows how to set up surface hopping on the ionized states of a molecule with EOM-IP-CCSD: the reference to give Q-Chem, the keywords, and the settings that matter. You need it for cation dynamics after photoionization.

## When to use it

> Use EOM-IP-CCSD for dynamics of a cation formed by ionization: the states are the ionized (N − 1 electron) states of the molecule you give Q-Chem.
>
> **Couplings:** coupling vectors from Q-Chem, or Baeck-An couplings from energies.

## Keywords

| Keyword | Example value | Meaning |
|---|---|---|
| `$molecule` charge and multiplicity | `0 1` | The neutral closed-shell molecule **before** ionization, not the cation. |
| `IP_STATES` | `[3]` | The n lowest ionized states, by default removing a β electron. One value, because symmetry is off. State 1 is the cation ground state. |
| `EOM_IP_ALPHA`, `EOM_IP_BETA` | — | Spin-specific alternatives to `IP_STATES` (untested). The initial-conditions script does not read them; use `IP_STATES`. |

The [shared keywords](README.md#keywords-shared-by-all-methods) (`METHOD`, `CALC_NAC`, `SYM_IGNORE`, convergence thresholds) apply too.

## Couplings allowed

Both kinds work; see [Couplings](../couplings.md#which-methods-allow-which-couplings).

- **Coupling vectors** (`vdoth = 0`): analytic EOM-IP-CCSD couplings from Q-Chem, with `CALC_NAC 2`.
- **Baeck-An couplings** (`vdoth = 2`): NewtonX computes them from energies, and the interface runs one gradient-only job per step.

## Template

Full input: [`docs/templates/ip.qchem.inp`](../templates/ip.qchem.inp), the template of the [methane-cation example](../../examples/methane_cation_eomip_full), which starts on the third CH₄⁺ state. Copy it to `JOB_NAD/qchem.inp`, change the molecule, and run as in [Your first trajectory](../first-trajectory.md#7-run). The method block is:

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

## Settings

| File | Setting | Suggestion |
|---|---|---|
| `control.dyn` | `nstat` | At most the n of `IP_STATES`. |
| `qchem.par` | [`nac_mode`](../qchem-par.md#nac_mode) | Keep the default, `nx`. Ionized states of small molecules are often close together, and all pairs matter. |
| `sh.inp` | [`vdoth`](../qchem-par.md#related-newtonx-settings) | `0`. Use `2` for large molecules, where each coupling job takes hours. |

## Pitfalls

- **Cation reference.** A cation in `$molecule` gives dication states. For the methane cation, the reference is neutral CH₄ (charge 0, multiplicity 1).
- **Unrestricted reference.** EOM-IP analytic gradients need an unrestricted reference. Q-Chem switches to it by itself and says so in the output (`Setting UNRESTRICTED=TRUE`); this is expected.

## Cost

About 60 s per step on 4 cores for the methane-cation example with 3 states; see [Validation](../validation.md#coupling-modes).

## See also

- [Couplings](../couplings.md): coupling vectors and Baeck-An couplings
- [Settings reference](../qchem-par.md): every `qchem.par` key and its default
- [Other methods](README.md): compare the four EOM flavors
