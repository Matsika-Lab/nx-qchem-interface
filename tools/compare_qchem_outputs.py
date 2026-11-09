#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Compare EOM-CC energies, target-state gradient and NACs of Q-Chem outputs against a reference.
usage: compare_outputs.py REF.out OUT.out [OUT.out ...]"""
import re, sys, numpy as np
def parse(f):
    L = open(f).read().splitlines(); E = []; G = {}; D = {}; A = B = None; full = None
    for i, l in enumerate(L):
        if re.match(r'\s*EOM[A-Z]+ transition\s+\d+/', l):
            m = re.search(r'Total energy\s*=\s*(-?\d+\.\d+)', L[i + 1]); E.append(float(m.group(1)))
        m = re.search(r'State A:.*:\s+(\d+)/', l); A = int(m.group(1)) if m else A
        m = re.search(r'State B:.*:\s+(\d+)/', l); B = int(m.group(1)) if m else B
        def blk(i):
            v = []; j = i + 3
            while j < len(L) and len(L[j].split()) == 4 and L[j].split()[0].isdigit():
                v.append([float(x) for x in L[j].split()[1:]]); j += 1
            return np.array(v)
        if re.match(r'\s*G_I, a\.u\.', l): G.setdefault(A, blk(i))
        if re.match(r'\s*G_J, a\.u\.', l): G.setdefault(B, blk(i))
        if 'NAC d^x_IJ (CI part)' in l: D.setdefault((A, B), blk(i))
        if 'Full Analytical Gradient' in l: full = i
    if full is not None and not G:
        n = len(L[full + 1].split()); rows = [[float(x) for x in L[full + 2 + r].split()[1:]] for r in range(3)]
        cols = []; k = full + 1
        while True:
            hdr = L[k].split()
            if not hdr or not all(h.isdigit() for h in hdr): break
            for c in range(len(hdr)): cols.append([float(L[k + 1 + r].split()[1 + c]) for r in range(3)])
            k += 4
        G['target'] = np.array(cols)
    return np.array(E), G, D
ref = parse(sys.argv[1])
for f in sys.argv[2:]:
    E, G, D = parse(f)
    dE = np.abs(E[:len(ref[0])] - ref[0]).max() * 1e6
    gk = [k for k in G if k in ref[1]]
    dG = max(np.abs(G[k] - ref[1][k]).max() for k in gk) if gk else (np.abs(G['target'] - ref[1][2]).max() if 'target' in G else float('nan'))
    dD = []; cos = []
    for k in D:
        if k in ref[2]:
            a, b = D[k], ref[2][k]; dD.append(np.abs(np.abs(a) - np.abs(b)).max()); cos.append(abs(np.sum(a * b)) / np.linalg.norm(a) / np.linalg.norm(b))
    print(f"{f}: max|dE| {dE:.2f} uEh, max|dG| {dG:.1e} au" + (f", max||d|-|d_ref|| {max(dD):.1e} au, min|cos| {min(cos):.6f}" if dD else ""))
