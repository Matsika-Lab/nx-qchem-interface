#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Plot a NewtonX surface-hopping trajectory run with the Q-Chem interface.

usage:
  plot_trajectory.py TRAJ_DIR [--title TEXT] [--coord LABEL:TYPE:ATOMS ...] [--out DIR]

TRAJ_DIR is the trajectory folder (the one holding RESULTS/). TYPE is bond, angle or
dihedral, and ATOMS are 1-based atom numbers separated by commas, for example
  --coord "C=C twist:dihedral:3,1,2,5"   --coord "C-N:bond:1,2"

Writes DIR/overview.png (default TRAJ_DIR/plots) and DIR/summary.json with the hops,
energy conservation and final populations.
"""
import argparse, json, os, re
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HARTREE_EV = 27.211386245988
BOHR_ANG = 0.529177210903
# Reference categorical palette (validated light-mode slots). States use slots 1-3 (+6, 8),
# coupling pairs use slots 4, 5, 7 so they never read as states.
STATE_COLORS = ["#2a78d6", "#eb6834", "#1baf7a", "#008300", "#e34948"]
PAIR_COLORS = ["#eda100", "#e87ba4", "#6250d6", "#c98500", "#d55181", "#9085e9"]
INK, INK2, GRID, SURFACE = "#0b0b0b", "#5f5e5a", "#e4e3df", "#fcfcfb"


def read_en(path):
    d = np.loadtxt(path, ndmin=2)
    return d[:, 0], d[:, 1:-2], d[:, -2], d[:, -1]  # t, E_k, E_active, E_tot (hartree)


def read_dyn(path, nat):
    """Active state and geometry (bohr) per step from RESULTS/dyn.out."""
    L = open(path).read().splitlines()
    steps, geoms = [], []
    for i, l in enumerate(L):
        m = re.match(r"STEP\s+(\d+)\s+Molecular dynamics on state\s+(\d+)\s+TIME =\s+([-\d.]+)", l)
        if m:
            steps.append((float(m.group(3)), int(m.group(2))))
        if re.match(r"\s*(Initial|New) geometry:\s*$", l) and len(geoms) < len(steps):
            g = [list(map(float, L[i + 1 + a].split()[2:5])) for a in range(nat)]
            geoms.append(g)
    t = np.array([s[0] for s in steps])
    act = np.array([s[1] for s in steps])
    return t, act, np.array(geoms)


def read_sh(path, nstat):
    """Populations and |v.h| per step from RESULTS/sh.out (records printed once per step)."""
    L = open(path).read().splitlines()
    recs = []
    i = 0
    while i < len(L):
        m = re.match(r"\s*(\d+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s*$", L[i])
        if m and i + nstat < len(L) and L[i + 1].startswith("Population:"):
            step = int(m.group(2))
            pops = [float(L[i + 1 + k].split()[2]) for k in range(nstat)]
            vh = None
            j = i + nstat + 1
            # |v.h| follows the populations, after the velocity-rescaling block on a hop step
            while j < len(L) and j < i + nstat + 40:
                if L[j].startswith("|v.h|="):
                    vh = [abs(float(x)) for x in L[j].split()[1:]]
                    break
                if re.match(r"\s*(\d+)\s+(\d+)\s+(\d+)\s+([-\d.]+)\s*$", L[j]):
                    break
                j += 1
            recs.append((step, pops, vh))
            i += nstat + 1
        else:
            i += 1
    # keep the last record of each step
    by_step = {}
    for s, p, v in recs:
        by_step[s] = (p, v)
    steps = sorted(by_step)
    pops = np.array([by_step[s][0] for s in steps])
    vh = np.array([by_step[s][1] if by_step[s][1] is not None else [np.nan] for s in steps], dtype=object)
    return np.array(steps), pops, vh


def internal(geom, kind, atoms):
    p = [geom[a - 1] * BOHR_ANG for a in atoms]
    if kind == "bond":
        return np.linalg.norm(p[0] - p[1])
    if kind == "angle":
        u, v = p[0] - p[1], p[2] - p[1]
        return np.degrees(np.arccos(np.clip(np.dot(u, v) / np.linalg.norm(u) / np.linalg.norm(v), -1, 1)))
    if kind == "dihedral":
        b0, b1, b2 = p[0] - p[1], p[2] - p[1], p[3] - p[2]
        b1n = b1 / np.linalg.norm(b1)
        v = b0 - np.dot(b0, b1n) * b1n
        w = b2 - np.dot(b2, b1n) * b1n
        x = np.dot(v, w)
        y = np.dot(np.cross(b1n, v), w)
        return np.degrees(np.arctan2(y, x))
    raise ValueError(kind)


def style(ax):
    ax.set_facecolor(SURFACE)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color(GRID)
    ax.tick_params(colors=INK2, labelsize=8.5, length=3)
    ax.yaxis.label.set_color(INK)
    ax.grid(axis="y", color=GRID, lw=0.6)
    ax.set_axisbelow(True)


def mark_hops(ax, hops, label=False):
    for th, a, b in hops:
        ax.axvline(th, color=INK2, lw=0.8, ls=(0, (2, 2)), zorder=0)
        if label:
            ax.annotate(f"{a}→{b}", (th, 1.0), xycoords=("data", "axes fraction"), xytext=(2, -2),
                        textcoords="offset points", fontsize=8, color=INK2, va="top")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("traj")
    ap.add_argument("--title", default=None)
    ap.add_argument("--coord", action="append", default=[])
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    R = os.path.join(a.traj, "RESULTS")
    out = a.out or os.path.join(a.traj, "plots")
    os.makedirs(out, exist_ok=True)

    nat = sum(1 for l in open(os.path.join(a.traj, "geom")) if l.strip())
    t, E, Eact, Etot = read_en(os.path.join(R, "en.dat"))
    nstat = E.shape[1]
    td, act, geoms = read_dyn(os.path.join(R, "dyn.out"), nat)
    steps, pops, vh = read_sh(os.path.join(R, "sh.out"), nstat)
    dt = t[1] - t[0] if len(t) > 1 else 0.5
    tp = steps * dt
    n = min(len(t), len(td))
    hops = [(td[i], act[i - 1], act[i]) for i in range(1, len(act)) if act[i] != act[i - 1]]

    coords = []
    for c in a.coord:
        label, kind, atoms = c.split(":")
        atoms = [int(x) for x in atoms.split(",")]
        coords.append((label, kind, np.array([internal(g, kind, atoms) for g in geoms])))

    npanel = 4 + len(coords)
    heights = [3, 2.2, 2.2, 1.6] + [1.6] * len(coords)
    fig, axes = plt.subplots(npanel, 1, figsize=(7.2, sum(heights) * 0.95 + 0.9), sharex=True,
                             gridspec_kw={"height_ratios": heights, "hspace": 0.18})
    fig.patch.set_facecolor(SURFACE)
    for ax in axes:
        style(ax)

    # 1. State energies with the active state
    ax = axes[0]
    e0 = E[0, 0]
    for k in range(nstat):
        ax.plot(t, (E[:, k] - e0) * HARTREE_EV, color=STATE_COLORS[k], lw=1.4, label=f"State {k + 1}")
    ax.plot(t[:n], (Eact[:n] - e0) * HARTREE_EV, color=INK, lw=3.2, alpha=0.22, solid_capstyle="round",
            label="Active state", zorder=1)
    ax.set_ylabel("Energy (eV)\nrel. to state 1 at t = 0", fontsize=9)
    mark_hops(ax, hops, label=True)
    ax.legend(loc="upper left", bbox_to_anchor=(1.01, 1.0), fontsize=8.5, frameon=False, labelcolor=INK)

    # 2. Populations
    ax = axes[1]
    for k in range(nstat):
        ax.plot(tp, pops[:, k], color=STATE_COLORS[k], lw=1.4, label=f"State {k + 1}")
    ax.set_ylim(-0.03, 1.03)
    ax.set_ylabel("Population |c|²", fontsize=9)
    mark_hops(ax, hops)
    ax.legend(loc="upper left", bbox_to_anchor=(1.01, 1.0), fontsize=8.5, frameon=False, labelcolor=INK)

    # 3. Coupling strength |v.d_kl| per pair
    ax = axes[2]
    pairs = [(i, j) for i in range(2, nstat + 1) for j in range(1, i)]
    V = np.array([np.array(v, dtype=float) if v is not None and len(v) == len(pairs) else np.full(len(pairs), np.nan) for v in vh])
    for p, (i, j) in enumerate(pairs):
        vabs = np.abs(V[:, p])  # sh.out prints v.h with its sign
        y = np.where(vabs > 0, vabs, np.nan)
        ax.plot(tp, y, color=PAIR_COLORS[p], lw=1.2, label=f"States {j}–{i}")
    ax.set_yscale("log")
    ax.set_ylabel("|v · d| (a.u.)", fontsize=9)
    mark_hops(ax, hops)
    ax.legend(loc="upper left", bbox_to_anchor=(1.01, 1.0), fontsize=8.5, frameon=False, labelcolor=INK)

    # 4. Total energy conservation
    ax = axes[3]
    dE = (Etot - Etot[0]) * HARTREE_EV * 1000
    ax.plot(t, dE, color=INK, lw=1.2)
    ax.set_ylabel("Total energy\nchange (meV)", fontsize=9)
    mark_hops(ax, hops)

    for ax, (label, kind, vals) in zip(axes[4:], coords):
        ax.plot(td[: len(vals)], vals, color=INK, lw=1.2)
        unit = "Å" if kind == "bond" else "deg"
        ax.set_ylabel(f"{label} ({unit})", fontsize=9)
        mark_hops(ax, hops)

    axes[-1].set_xlabel("Time (fs)", fontsize=9, color=INK)
    axes[-1].set_xlim(t[0], t[-1])
    title = a.title or os.path.basename(os.path.abspath(a.traj))
    fig.suptitle(title, x=0.02, ha="left", fontsize=11.5, color=INK, fontweight="bold")
    sub = f"{len(hops)} hop(s) · final state {act[-1]} · max |ΔE_tot| {np.max(np.abs(dE)):.1f} meV · {t[-1]:.2f} fs"
    fig.text(0.02, 0.985 - 0.35 / fig.get_figheight(), sub, fontsize=9, color=INK2, ha="left", va="top")
    fig.subplots_adjust(left=0.13, right=0.80, top=1 - 0.75 / fig.get_figheight(), bottom=0.6 / fig.get_figheight())
    fig.savefig(os.path.join(out, "overview.png"), dpi=150, facecolor=SURFACE)

    summary = {
        "time_fs": float(t[-1]), "steps": int(len(t)), "nstat": int(nstat),
        "initial_state": int(act[0]), "final_state": int(act[-1]),
        "hops": [{"t_fs": float(h[0]), "from": int(h[1]), "to": int(h[2])} for h in hops],
        "max_abs_dEtot_meV": float(np.max(np.abs(dE))), "final_dEtot_meV": float(dE[-1]),
        "final_populations": [float(x) for x in pops[-1]],
    }
    json.dump(summary, open(os.path.join(out, "summary.json"), "w"), indent=2)
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
