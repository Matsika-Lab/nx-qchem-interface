#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Turn a Q-Chem frequency calculation into NewtonX initcond input.

usage:
  qchem_freq_to_nx.py QCHEM_FREQ.out OUTDIR

The Q-Chem job must have run with MOLDEN_FORMAT TRUE. The last MOLDEN block of the
output is read, and two files are written:
  OUTDIR/molden.freq  all 3N modes, as NewtonX expects: the translations and rotations
                      first, as zero frequencies and zero vectors, then the vibrations
  OUTDIR/geom         the geometry in bohr, in NewtonX format (symbol, Z, x, y, z, mass)
Use them with initcond.pl (iprog = 5, nm_flag = 2, file_nmodes = molden.freq).
"""
import os, re, sys

# isotope masses (u) of the most abundant isotope, and atomic numbers
ELEMENTS = {
    'H': (1, 1.00782504), 'He': (2, 4.00260325), 'Li': (3, 7.01600450), 'Be': (4, 9.01218220),
    'B': (5, 11.00930540), 'C': (6, 12.0), 'N': (7, 14.00307401), 'O': (8, 15.99491464),
    'F': (9, 18.99840320), 'Ne': (10, 19.99244018), 'Na': (11, 22.98976928), 'Mg': (12, 23.98504170),
    'Al': (13, 26.98153863), 'Si': (14, 27.97692653), 'P': (15, 30.97376163), 'S': (16, 31.97207100),
    'Cl': (17, 34.96885268), 'Ar': (18, 39.96238312), 'Br': (35, 78.91833710), 'I': (53, 126.904473),
}


def main():
    if len(sys.argv) != 3 or sys.argv[1] in ('-h', '--help'):
        sys.exit(__doc__)
    src, out = sys.argv[1], sys.argv[2]
    txt = open(src).read()
    blocks = re.findall(r'=+ MOLDEN-FORMATTED INPUT FILE FOLLOWS =+\n(.*?)=+ END OF MOLDEN-FORMATTED', txt, re.S)
    blocks = [b for b in blocks if '[FR-NORM-COORD]' in b]
    if not blocks:
        sys.exit(f'{src}: no MOLDEN block with normal modes; run the frequency job with MOLDEN_FORMAT TRUE')
    blk = blocks[-1]

    def section(name):
        m = re.search(r'\[' + re.escape(name) + r'\][^\n]*\n(.*?)(?=\n\[|\Z)', blk, re.S)
        return [l for l in m.group(1).splitlines() if l.strip()]

    freqs = [float(l) for l in section('FREQ')]
    coord = [l.split() for l in section('FR-COORD')]
    nat = len(coord)
    modes, cur = [], None
    for l in section('FR-NORM-COORD'):
        if l.strip().lower().startswith('vibration'):
            cur = []
            modes.append(cur)
        else:
            cur.append([float(x) for x in l.split()])
    if len(modes) != len(freqs):
        sys.exit(f'{src}: {len(freqs)} frequencies but {len(modes)} modes')
    if any(f <= 0 for f in freqs):
        sys.exit(f'{src}: imaginary frequency {min(freqs):.1f} cm-1; the geometry is not a minimum')
    for c in coord:
        if c[0].capitalize() not in ELEMENTS:
            sys.exit(f'{src}: element {c[0]} not in the mass table of {os.path.basename(__file__)}; add it there')

    ntriv = 3 * nat - len(freqs)  # 6, or 5 for a linear molecule
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, 'molden.freq'), 'w') as f:
        f.write('[Molden Format]\n[FREQ]\n')
        f.writelines('0.0\n' for _ in range(ntriv))
        f.writelines('%.4f\n' % v for v in freqs)
        f.write('[FR-COORD]\n')
        f.writelines('%s %s %s %s\n' % tuple(c[:4]) for c in coord)
        f.write('[FR-NORM-COORD]\n')
        n = 0
        for _ in range(ntriv):
            n += 1
            f.write('vibration %d\n' % n)
            f.writelines('0.0 0.0 0.0\n' for _a in range(nat))
        for m in modes:
            n += 1
            f.write('vibration %d\n' % n)
            f.writelines('%.8f %.8f %.8f\n' % tuple(r) for r in m)
    with open(os.path.join(out, 'geom'), 'w') as f:
        for c in coord:
            s = c[0].capitalize()
            z, mass = ELEMENTS[s]
            f.write(' %-2s %5.1f %14.8f %14.8f %14.8f %14.8f\n' % (s, z, float(c[1]), float(c[2]), float(c[3]), mass))
    print(f'{out}/molden.freq and {out}/geom written: {nat} atoms, {len(freqs)} vibrations, '
          f'{ntriv} zero modes added, lowest frequency {freqs[0]:.1f} cm-1')


if __name__ == '__main__':
    main()
