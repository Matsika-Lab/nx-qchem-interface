[Home](../../README.md) / [Methods](README.md) / EOM-SF-CCSD

# EOM-SF-CCSD

> **Use it for** dynamics that reach the ground state, such as decay through a conical intersection with S₀, or bond twisting and breaking. Spin-flip treats the ground and low excited singlets on the same footing.
> **Couplings:** Baeck-An couplings from energies; coupling vectors from Q-Chem with the caveat below.

## Caveats

- **Coupling vectors are not documented by Q-Chem for spin-flip.** The Q-Chem manuals (5.4 to 6.2) list EOM-CC couplings for EE, IP and EA. Q-Chem 5.4 nevertheless computes EOM-SF couplings without a warning. The interface allows them, but prints a warning at the start of the trajectory. Check them for your system, or use `vdoth = 2`, which needs only EOM-SF gradients.
- **The Ms = 0 triplet is one of the states.** Spin-flip from a high-spin triplet also gives the Ms = 0 component of that triplet. It counts in `nstat`, and it has no coupling to the singlets.
- **The UHF triplet reference can switch solutions.** Along a twist, two stable UHF solutions of the reference can cross. Reusing orbitals between steps keeps the trajectory on the one it started on, even when it becomes the higher one; Q-Chem's stability analysis reports it as stable. CCSD then often stops converging a few steps later. The interface checks every step against a fresh-guess SCF and warns (`scf_check`, on by default for open-shell references). ROHF is not an alternative, because Q-Chem has no ROHF gradients. The [ethylene example](../../examples/ethylene_eomsf) stops at 9 fs for this reason.
- CCSD on the triplet reference can stall near 10⁻⁹; use `CC_CONVERGENCE 8`, as the template does.

## Reference and states

| Reference | `$molecule` line | States |
|---|---|---|
| high-spin triplet (two unpaired electrons) | e.g. `0 3` | `SF_STATES [n]`: S₀, the Ms = 0 triplet and low singlets, ordered by energy |

Set `nstat` in `control.dyn` to at most n. Check the order of the states at your starting geometry with a single-point run before you choose `nstatdyn`.

## Template

Full input: [`docs/templates/sf.qchem.inp`](../templates/sf.qchem.inp), the template of the [ethylene example](../../examples/ethylene_eomsf). Copy it to `JOB_NAD/qchem.inp` and change the molecule. The method block is:

```text
$rem
METHOD            EOM-CCSD
SF_STATES         [3]
BASIS             cc-pVDZ
CALC_NAC          2
SYM_IGNORE        TRUE
SCF_CONVERGENCE           9
CC_CONVERGENCE            8
EOM_DAVIDSON_CONVERGENCE  9
$end
```

For Baeck-An couplings, set `vdoth = 2` in `sh.inp`. The same template works: the interface removes `CALC_NAC` and sets `JOBTYPE FORCE`.

## Method-specific keywords

| Keyword | Value | Why |
|---|---|---|
| `SF_STATES` | `[n]` | Number of spin-flip states, including the Ms = 0 triplet. |
| `CC_CONVERGENCE` | `8` | Avoids stalled CCSD on the triplet reference. |

The [shared keywords](README.md#keywords-shared-by-all-methods) apply too.

## Settings

| File | Setting | Suggestion |
|---|---|---|
| `qchem.par` | `nac_mode` | default `nx` |
| `sh.inp` | `vdoth` | `2` if you prefer not to rely on the undocumented coupling vectors; otherwise `0` |

## Run it

The example [`examples/ethylene_eomsf`](../../examples/ethylene_eomsf) starts on the ππ* state of ethylene, about 145 s per step on 4 cores.

## See also

- [EOM-EE](eom-ee.md)
- [Couplings](../couplings.md)
- [Settings reference](../par-reference.md)
