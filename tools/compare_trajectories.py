#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Compare trajectories that start from the same initial condition (for example the
three coupling modes).

usage:
  compare_trajectories.py LABEL=TRAJ_DIR [LABEL=TRAJ_DIR ...] --out FIGURE.png [--title TEXT]

Draws one population panel per trajectory (same state colors in every panel), then the
active state and the total-energy change of all trajectories, distinguished by line style.
"""
import argparse, os, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from plot_trajectory import read_en, read_dyn, read_sh, style, STATE_COLORS, INK, INK2, SURFACE, HARTREE_EV

STYLES = ["-", (0, (5, 2)), (0, (1.5, 1.5)), (0, (6, 2, 1.5, 2))]
GRAYS = [INK, "#3d3d3a", "#5f5e5a", "#7d7c77"]


def load(d):
    nat = sum(1 for l in open(os.path.join(d, "geom")) if l.strip())
    t, E, Eact, Etot = read_en(os.path.join(d, "RESULTS", "en.dat"))
    td, act, _ = read_dyn(os.path.join(d, "RESULTS", "dyn.out"), nat)
    steps, pops, _ = read_sh(os.path.join(d, "RESULTS", "sh.out"), E.shape[1])
    dt = t[1] - t[0]
    return dict(t=t, Etot=Etot, td=td, act=act, tp=steps * dt, pops=pops, nstat=E.shape[1])


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("runs", nargs="+")
    ap.add_argument("--out", required=True)
    ap.add_argument("--title", default="Trajectory comparison")
    a = ap.parse_args()
    runs = []
    for r in a.runs:
        label, d = r.split("=", 1)
        runs.append((label, load(d)))
    n = len(runs)
    heights = [1.6] * n + [1.4, 1.4]
    fig, axes = plt.subplots(n + 2, 1, figsize=(7.2, sum(heights) * 0.95 + 1.0), sharex=True,
                             gridspec_kw={"height_ratios": heights, "hspace": 0.22})
    fig.patch.set_facecolor(SURFACE)
    for ax in axes:
        style(ax)
    tmax = min(r["t"][-1] for _, r in runs)
    for ax, (label, r) in zip(axes, runs):
        for k in range(r["nstat"]):
            ax.plot(r["tp"], r["pops"][:, k], color=STATE_COLORS[k], lw=1.3, label=f"State {k + 1}")
        for i in range(1, len(r["act"])):
            if r["act"][i] != r["act"][i - 1]:
                ax.axvline(r["td"][i], color=INK2, lw=0.8, ls=(0, (2, 2)), zorder=0)
        ax.set_ylim(-0.03, 1.03)
        ax.set_ylabel(f"{label}\npopulation", fontsize=9)
    axes[0].legend(loc="upper left", bbox_to_anchor=(1.01, 1.0), fontsize=8.5, frameon=False, labelcolor=INK)

    ax = axes[n]
    for i, (label, r) in enumerate(runs):
        ax.step(r["td"], r["act"], where="post", color=GRAYS[i], ls=STYLES[i], lw=1.4, label=label)
    nst = runs[0][1]["nstat"]
    ax.set_yticks(range(1, nst + 1))
    ax.set_ylim(0.6, nst + 0.4)
    ax.set_ylabel("Active state", fontsize=9)
    ax.legend(loc="upper left", bbox_to_anchor=(1.01, 1.0), fontsize=8.5, frameon=False, labelcolor=INK)

    ax = axes[n + 1]
    for i, (label, r) in enumerate(runs):
        ax.plot(r["t"], (r["Etot"] - r["Etot"][0]) * HARTREE_EV * 1000, color=GRAYS[i], ls=STYLES[i], lw=1.3, label=label)
    ax.set_ylabel("Total energy\nchange (meV)", fontsize=9)
    ax.legend(loc="upper left", bbox_to_anchor=(1.01, 1.0), fontsize=8.5, frameon=False, labelcolor=INK)
    axes[-1].set_xlabel("Time (fs)", fontsize=9, color=INK)
    axes[-1].set_xlim(0, tmax)
    fig.suptitle(a.title, x=0.02, ha="left", fontsize=11.5, color=INK, fontweight="bold")
    fig.subplots_adjust(left=0.13, right=0.80, top=1 - 0.6 / fig.get_figheight(), bottom=0.6 / fig.get_figheight())
    fig.savefig(a.out, dpi=150, facecolor=SURFACE)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
