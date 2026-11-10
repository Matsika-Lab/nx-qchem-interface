[Home](../README.md) / Couplings

# Couplings

Surface hopping needs, at every step, how strongly each pair of electronic states is coupled. This page explains the two kinds of coupling the interface supports, which methods allow them, and how the interface obtains and cleans them.

## Which methods allow which couplings

| Method | Coupling vectors from Q-Chem (`vdoth = 0`) | Time-dependent Baeck-An (TD-BA) couplings from energies (`vdoth = 2`) |
|---|---|---|
| EOM-IP-CCSD | yes | yes |
| EOM-EA-CCSD | yes | yes |
| EOM-EE-CCSD | yes | yes |
| EOM-SF-CCSD | computed, but not documented by Q-Chem; the interface warns | yes |

Overlap-based couplings (`vdoth = 1` or negative in NewtonX) are not available, because Q-Chem's EOM-CC code does not provide wavefunction overlaps.

## Where couplings enter the dynamics

NewtonX propagates the electronic coefficients $`c_k`$ along the classical trajectory:

```math
\frac{dc_k}{dt} = -\frac{i}{\hbar}E_k c_k - \sum_l c_l\,\sigma_{kl}, \qquad \sigma_{kl} = \mathbf{v}\cdot\mathbf{d}_{kl}
```

Here $`E_k`$ is the energy of state $`k`$, $`\mathbf{v}`$ the nuclear velocity, and $`\sigma_{kl}`$ the time-derivative coupling. In words: population moves between two states at a rate set by how fast the nuclei move along the coupling vector between them. The probability of hopping from the active state $`a`$ to state $`k`$ is proportional to $`-\mathrm{Re}(c_k c_a^{*}\,\sigma_{ka})`$.

## Nonadiabatic coupling vectors (`vdoth = 0`)

The nonadiabatic coupling (derivative coupling) vector between states $`I`$ and $`J`$ is

```math
\mathbf{d}_{IJ} = \langle \Psi_I \,|\, \nabla_{\mathbf{R}} \Psi_J \rangle = \frac{\mathbf{h}_{IJ}}{E_J - E_I}, \qquad \mathbf{h}_{IJ} = \langle \Psi_I \,|\, \nabla_{\mathbf{R}} \hat H \,|\, \Psi_J \rangle
```

In words: how much state $`J`$ changes, as seen by state $`I`$, when the nuclei move. It grows as the two states approach each other in energy.

Q-Chem computes $`\mathbf{h}_{IJ}`$ with Szalay's summed-state method, $`\mathbf{h}_{IJ} = \tfrac12(\mathbf{G}_{I+J} - \mathbf{G}_I - \mathbf{G}_J)`$, from analytic gradients of the two states and of a fictitious summed state (Tajti and Szalay, 2009; Faraji, Matsika and Krylov, 2018). It prints $`\mathbf{d}_{IJ}`$ as `NAC d^x_IJ (CI part)`, in bohr⁻¹, and the interface passes it to NewtonX unchanged apart from its sign (see [Coupling signs](#coupling-signs)).

**Cost.** One Q-Chem job gives the couplings between its target state and all other states, plus the gradients of all states. How many jobs run per step is set by [`nac_mode`](qchem-par.md#nac_mode).

## TD-BA couplings (`vdoth = 2`)

The TD-BA approximation estimates the time-derivative coupling from the energy gap alone. NewtonX computes it from the energies of the last few steps:

```math
\sigma_{IJ} \approx \frac{\mathrm{sign}(\Delta E_{IJ})}{2}\sqrt{\frac{\ddot{\Delta E}_{IJ}}{\Delta E_{IJ}}}, \qquad \Delta E_{IJ} = E_I - E_J
```

Here $`\ddot{\Delta E}_{IJ}`$ is the second time derivative of the gap. In words: a gap that closes and reopens quickly signals strong coupling. NewtonX sets $`\sigma_{IJ} = 0`$ when the gap exceeds `BA_DE` (default 2 eV), and these thresholds are set in NewtonX's `auxnac.inp`. After a hop, momentum is rescaled along the velocity, because there is no coupling vector.

**Cost.** One gradient-only Q-Chem job per step, with no `CALC_NAC`. In our [benchmark](validation.md) a gradient job took 36% less time than a coupling job, and n − 1 coupling jobs are replaced by one. The template comes from `JOB_AD/qchem.inp` (or `JOB_NAD/qchem.inp` if there is no `JOB_AD`); the interface removes `CALC_NAC` and sets `JOBTYPE FORCE`.

Reference: T. do Casal, Toldo, Pinheiro and Barbatti, *Open Research Europe* 1, 49 (2021).

## Which to use

Start with coupling vectors (`vdoth = 0`): they are analytic EOM-CCSD couplings (the CI part, which dominates for most systems), not an estimate from energies. Use TD-BA couplings when coupling jobs are too expensive for the molecule, or with EOM-SF if you prefer not to rely on its undocumented coupling vectors.

## Letting NewtonX choose the pairs

With [`nac_mode`](qchem-par.md#nac_mode) `= nx` (the default), the interface computes the pairs NewtonX asks for at each step. NewtonX decides from `kross`, `cascade`, `current`, `never_state` and `include_pair` in `jiri.inp`, and from the gap threshold `thres` in `control.dyn` (see the NewtonX manual, "Nonadiabatic dynamics control"). The interface runs the fewest Q-Chem jobs that give those pairs, starting with the active state. Pairs NewtonX did not ask for are returned as zero, and when NewtonX asks for none, the step runs a cheaper gradient-only job.

NewtonX's defaults ask for every pair, which takes n − 1 jobs for n states. Later jobs reuse the first job's geometry and orbitals, so with 3 states a step costs a little under twice one job.

## Coupling modes

Setting `nac_mode` to `full`, `carry` or `active` overrides NewtonX's list. With these modes, the forces are the same; only the electronic propagation changes:

- **`full`** computes every pair, every step.
- **`carry`** computes the pairs with the active state and keeps the last computed value of the others, sign-aligned. Those values are stale until the pair is computed again.
- **`active`** computes the pairs with the active state only. Couplings between two inactive states are zero, so population cannot flow directly between them. The amplitudes $`c_k`$ of inactive states then drift, and so do the probabilities of later hops into those states. The error is largest when two inactive states are close in energy, and NewtonX's decoherence correction reduces it.

The [methane examples](../examples/README.md) run one initial condition in the three modes; see the [comparison](validation.md#coupling-modes).

## Adiabatic and mixed dynamics

NewtonX hands the interface the `JOB_AD` input for adiabatic dynamics, and for adiabatic steps when you set a gap threshold `thres`. It does the same whenever `vdoth = 2`. These steps need only the gradient of the active state, so the interface runs one gradient-only job built from `JOB_AD/qchem.inp`, whatever `nac_mode` is. The same template as `JOB_NAD` works: the interface removes `CALC_NAC` and sets `JOBTYPE FORCE`. If you provide no `JOB_AD`, NewtonX copies `JOB_NAD`.

## Coupling signs

Each Q-Chem run fixes the sign of every wavefunction arbitrarily, so a coupling vector can come back with the opposite sign from one step to the next: $`\mathbf{d}_{kl} \to s_k s_l\,\mathbf{d}_{kl}`$ with $`s = \pm 1`$. A flipped sign reverses $`\sigma_{kl}`$ and sends population the wrong way.

NewtonX's `escalar` program flips each new vector so that it points along its value one step earlier. When a pair has no value one step earlier, for example right after a hop, the interface first aligns it to the last sign-corrected vector stored for that pair in `INFO_RESTART/nac_phase_ref`. It reports each alignment in `RESULTS/nx.log`:

```text
run-qchem-eom.pl: Coupling pair 2 (states 2-3): aligned to stored reference from t=0.0000 (cos=-0.6993, phase=-1)
```

Couplings with a norm below 10⁻³ a.u. are too weak to define a direction: they neither replace a stored reference nor get aligned to one, and their sign has no effect on the dynamics. If the two vectors are nearly perpendicular (|cos θ| below [`phase_warn`](qchem-par.md)), the sign is uncertain, and the interface warns. Pairs are numbered the NewtonX way: 0 = states 1–2, 1 = states 1–3, 2 = states 2–3, 3 = states 1–4, and so on.

### NewtonX 2.6

NewtonX 2.6 adds its own sign check, run after the interface when `getphase = 1` in `sh.inp` (the 2.6 default for `vdoth = 0`). It flips each vector that points against a linear extrapolation from the two previous steps, $`2\,\mathbf{d}(t-\Delta t) - \mathbf{d}(t-2\Delta t)`$.

For EOM-CC couplings, this extrapolation fails in two common cases:
- **A pair that was zero at the previous step** (an adiabatic step, or a pair not computed) gets the reference $`-\mathbf{d}(t-2\Delta t)`$, which points against its last vector.
- **A coupling that decays fast after a spike near a crossing.** When it falls by more than half per step, the reference again points roughly along $`-\mathbf{d}(t-2\Delta t)`$. In a 2.6 test, $`|\mathbf{d}_{23}|`$ fell from 274 to 31 to 13.5 bohr⁻¹, and NewtonX flipped the vector against its previous value at the next two steps (cos −0.60, then −0.21).

The interface has already aligned the signs, so on NewtonX 2.6 it keeps them. It writes the extrapolation input `TEMP/nad_vectors-2dt` so that the reference equals its own vectors, and NewtonX's check then changes nothing. No setting is needed, and NewtonX 2.4 and 2.6 give the same signs. Setting `getphase = 0` skips NewtonX's check altogether, with the same result.

## After a hop

After a hop, NewtonX calls the interface again at the same geometry for the gradient of the new state. A coupling job has already computed the gradients of all states, and they do not depend on which state the job targeted, so the interface reuses them without running Q-Chem. If no gradient of the new state exists, as with gradient-only steps, Q-Chem runs again, and its output is archived as `<time>.after_hop.out.gz`.

## See also

- [Settings reference](qchem-par.md)
- [Method tutorials](methods/README.md)
- [Examples](../examples/README.md)
