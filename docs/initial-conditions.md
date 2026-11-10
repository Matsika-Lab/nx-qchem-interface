[Home](../README.md) / Initial conditions and spectra

# Initial conditions and spectra

NewtonX's `initcond.pl` samples geometries and velocities (for example a Wigner distribution), and can check each point's vertical energies and intensities. That gives an absorption-type spectrum from the nuclear ensemble, and lets you keep only points whose excitation falls in an energy window. With Q-Chem, `initcond.pl` calls [`run-qchem-eom-initcond.pl`](../run-qchem-eom-initcond.pl) once per point; the [installer](installation.md) registers it.

## What is computed

For each geometry, one Q-Chem single point is built from `JOB_AD/qchem.inp`. The program removes `CALC_NAC`, `CC_STATE_TO_OPT` and `JOBTYPE`, and adds the keywords the intensity needs:

| Method | NewtonX state 1 | NewtonX state *k* (k ≥ 2) | Intensity of 1 → k | Keywords added |
|---|---|---|---|---|
| EOM-EE | CCSD reference (ground state) | EOM-EE state k − 1 | oscillator strength | `CC_TRANS_PROP 1` |
| EOM-SF | EOM-SF state 1 (ground state) | EOM-SF state k | oscillator strength from SF state 1 | `CC_STATE_TO_OPT [1,1]`, `CC_TRANS_PROP 1` |
| EOM-IP | neutral reference | EOM-IP state k − 1 | Dyson-orbital norm, left × right | `CC_DO_DYSON TRUE` |
| EOM-EA | reference | EOM-EA state k − 1 | Dyson-orbital norm, left × right | `CC_DO_DYSON TRUE` |

**State numbering differs from the dynamics** for EE, IP and EA. In `initcond.pl`, state 1 is the reference, while in the dynamics the EOM states start at 1. So initial-conditions state *k* is dynamics state *k* − 1. For example, choose `nstatdyn = 2` to start the dynamics on EOM-EE state 2, which is state 3 in `initqp_input`. For EOM-SF the numbering is the same in both.

For IP, the intensity is the product of the left and right Dyson-orbital norms. EOM-CC gives a left and a right Dyson orbital, and this product is the EOM-CC counterpart of the squared norm in NewtonX's "DO norm" approximation for photoelectron spectra. For EA, the "excitation energies" are electron-attachment energies, which are negative for bound states.

Full photoelectron spectra with ezDyson cross sections (NewtonX's `ICS_COMP = 2`) are not supported.

## Setting it up

```text
IC/
├── initqp_input     NewtonX initial-condition settings
├── geom             equilibrium geometry (bohr, NewtonX format)
├── molden.freq      normal modes (see Your first trajectory, step 4)
├── qchem.par        optional; only nt is used here
└── JOB_AD/
    └── qchem.inp    the same template as for the dynamics (CALC_NAC is removed)
```

An `initqp_input` that keeps points whose excitation lies within 9.7 ± 1.0 eV (`kvert = 0`: use the `evert` given here). Here the window is meant for the S₂ excitation of an EOM-EE molecule, which is state 3 in `initcond.pl`:

```text
&dat
 nact = 2
 numat = 6
 npoints = 100
 file_geom = geom
 iprog = 5
 nm_flag = 2
 file_nmodes = molden.freq
 chk_e = 1
 nis = 1
 nfs = 3
 kvert = 0
 evert = 9.7
 de = 1.0
 prog = 22
/
```

`nis` must be 1: transitions start from state 1. States 2 to `nfs` are all checked, each in its own `final_output.1.<k>`; use the file of the state you start on (`final_output.1.3` here). The template must ask for enough states: `nfs − 1` for EE, IP and EA, and `nfs` for SF. Run it with `$NX/initcond.pl > initcond.log`.

For each point, `initcond.log` shows the states (here the first sampled point of methaniminium):

```text
[STATE INFORMATION] EOM-EE-CCSD (Q-Chem)
  state       energy (a.u.)      dE (eV)   oscillator strength
  1            -94.69367206
  2            -94.39620412       8.0945   0.001147
  3            -94.33825139       9.6715   0.337159
[END STATE INFORMATION]
```

and `final_output.1.3` whether it is kept:

```text
 Vertical excitation (eV):      9.6715  Is Ev in the required range? YES
 Oscillator strength:           0.3372
```

NewtonX's `$NX/makedir.pl` then makes one trajectory folder per accepted point.

## See also

- [Your first trajectory](first-trajectory.md)
- [Method tutorials](methods/README.md)
