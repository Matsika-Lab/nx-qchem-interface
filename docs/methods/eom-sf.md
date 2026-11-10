[Home](../../README.md) / [Methods](README.md) / EOM-SF-CCSD

# EOM-SF-CCSD

This page shows how to set up surface hopping with spin-flip EOM-CCSD from a high-spin triplet reference: the keywords, the couplings you can use, and the settings that matter. You need it when the dynamics reaches the ground state.

## When to use it

> Use EOM-SF-CCSD for dynamics that reach the ground state, such as decay through a conical intersection with S₀, or bond twisting and breaking. Spin-flip treats the ground and low excited singlets on the same footing.
>
> **Couplings:** Baeck-An couplings from energies; coupling vectors from Q-Chem, which Q-Chem computes but does not document for spin-flip.

## Keywords

| Keyword | Example value | Meaning |
|---|---|---|
| `$molecule` charge and multiplicity | `0 3` | A high-spin triplet (two unpaired electrons), the reference of the spin flip. |
| `SF_STATES` | `[3]` | The n lowest spin-flip states, ordered by energy: S₀, the Ms = 0 triplet and low singlets. One value, because symmetry is off. |
| `CC_CONVERGENCE` | `8` | Looser than the shared `9`; avoids stalled CCSD on the triplet reference. |

The other [shared keywords](README.md#keywords-shared-by-all-methods) (`METHOD`, `CALC_NAC`, `SYM_IGNORE`, `SCF_CONVERGENCE`, `EOM_DAVIDSON_CONVERGENCE`) apply too.

## Couplings allowed

See [Couplings](../couplings.md#which-methods-allow-which-couplings).

- **Coupling vectors** (`vdoth = 0`): computed by Q-Chem 5.4 without a warning, but not documented by Q-Chem for spin-flip. The interface allows them and prints a warning at the start of the trajectory.
- **Baeck-An couplings** (`vdoth = 2`): need only EOM-SF gradients. The same template works: the interface removes `CALC_NAC` and sets `JOBTYPE FORCE`.

## Template

Full input: [`docs/templates/sf.qchem.inp`](../templates/sf.qchem.inp), the template of the [ethylene example](../../examples/ethylene_eomsf), which starts on the ππ* state of ethylene. Copy it to `JOB_NAD/qchem.inp`, change the molecule, and run as in [Your first trajectory](../first-trajectory.md#7-run). The method block is:

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

## Settings

| File | Setting | Suggestion |
|---|---|---|
| `control.dyn` | `nstat` | At most the n of `SF_STATES`, counting the Ms = 0 triplet. |
| `control.dyn` | `nstatdyn` | Check the order of the states at your starting geometry with a single-point run before you choose it. |
| `qchem.par` | [`nac_mode`](../qchem-par.md#nac_mode) | Keep the default, `nx`. |
| `qchem.par` | [`scf_check`](../qchem-par.md#settings) | Keep the default, `auto`, which turns it on for the triplet reference. |
| `sh.inp` | [`vdoth`](../qchem-par.md#related-newtonx-settings) | `2` if you prefer not to rely on the undocumented coupling vectors; otherwise `0`. |

## Pitfalls

<a id="caveats"></a>

- **Coupling vectors are not documented by Q-Chem for spin-flip.** The Q-Chem manuals (5.4 to 6.2) list EOM-CC couplings for EE, IP and EA. Q-Chem 5.4 nevertheless computes EOM-SF couplings without a warning. The interface allows them, but prints a warning at the start of the trajectory. Check them for your system, or use `vdoth = 2`, which needs only EOM-SF gradients.
- **The Ms = 0 triplet is one of the states.** Spin-flip from a high-spin triplet also gives the Ms = 0 component of that triplet. It counts in `nstat`, and it has no coupling to the singlets.
- **The UHF triplet reference can switch solutions.** Along a twist, two stable UHF solutions of the reference can cross. Reusing orbitals between steps keeps the trajectory on the one it started on, even when it becomes the higher one; Q-Chem's stability analysis reports it as stable. CCSD then often stops converging a few steps later. The interface checks every step against a fresh-guess SCF and warns (`scf_check`, on by default for open-shell references). ROHF is not an alternative, because Q-Chem has no ROHF gradients. The [ethylene example](../../examples/ethylene_eomsf) stops at 9 fs for this reason.
- **Stalled CCSD.** CCSD on the triplet reference can stall near 10⁻⁹; use `CC_CONVERGENCE 8`, as the template does.

## Cost

About 150 s per step on 4 cores for the [ethylene example](../../examples/ethylene_eomsf) with 3 states; see [Validation](../validation.md) for what each option costs.

## See also

- [EOM-EE](eom-ee.md): excited states of a closed-shell molecule
- [Couplings](../couplings.md): coupling vectors and Baeck-An couplings
- [Settings reference](../qchem-par.md): every `qchem.par` key and its default
