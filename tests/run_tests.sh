#!/bin/bash
#
# Regression tests for run-qchem-eom.pl.
#
# Real Q-Chem outputs (tests/data/*/outputs) are replayed through the interface
# step by step with a stand-in "qchem" command, and NewtonX's own escalar does
# the phase correction. No Q-Chem run is needed; NewtonX 2.x must be installed
# and $NX must point to its bin directory.
#
# usage: tests/run_tests.sh [path/to/run-qchem-eom.pl]
#
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT=$(readlink -f "${1:-$HERE/../run-qchem-eom.pl}")
: "${NX:?Set NX to the NewtonX bin directory}"
[ -x "$NX/escalar" ] || { echo "escalar not found in \$NX=$NX"; exit 2; }
export PATH="$HERE/fake_qchem:$PATH"
export QCSCRATCH=$(mktemp -d)
WORK=$(mktemp -d)
[ -n "${KEEP:-}" ] && echo "work: $WORK" || trap 'rm -rf "$WORK" "$QCSCRATCH"' EXIT
pass=0; fail=0
ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail+1)); }

# new_traj <case> <name> [qchem.par lines...]: fresh trajectory folder, prints TEMP path
new_traj() {
  local c=$HERE/data/$1 w=$WORK/$2; shift 2
  mkdir -p $w/TEMP $w/INFO_RESTART $w/DEBUG $w/snap
  cp -r $c/JOB_NAD $w/TEMP/; cp $c/geom $w/TEMP/geom
  if [ $# -gt 0 ]; then printf '%s\n' "$@" > $w/TEMP/qchem.par; fi
  echo $w/TEMP
}
# step <tempdir> <output.gz> <istep>: run one step, stdout+stderr to <tempdir>/../snap/<t>.log, returns exit code
step() {
  local d=$1 out=$2 i=$3 t nat nstat nsd
  t=$(basename $out .out.gz)
  nat=$(grep -c . $d/geom)
  nstat=$(zcat $out | grep -m1 -oE '(IP|EA|EE|SF)_STATES *\[[0-9]+\]' | grep -oE '[0-9]+')
  nsd=$(zcat $out | grep -m1 CC_STATE_TO_OPT | grep -oE ',[0-9]+' | tr -d ,)
  echo "$nat,$i,$nstat,$nsd,0,1,0.25,$t,100,0,200,0,100,1,0,22,1,0.5,0.5" > $d/control.d
  ( cd $d && REPLAY_OUT=$out perl "$SCRIPT" > ../snap/$t.log 2>&1 )
  local rc=$?
  [ -f $d/nad_vectors ] && cp $d/nad_vectors $d/../snap/$t.nadv
  return $rc
}
replay() { # replay <tempdir> <case>: all steps in order
  local d=$1 i=0
  for f in $(ls $HERE/data/$2/outputs/*.out.gz | sort -t/ -k1 -V); do
    step $d $f $i || return 1; i=$((i+1))
  done
}
nphase_bad() { python3 $HERE/check_phase.py $1 $2 | awk '/sign inconsistencies/ {print $3}'; }

echo "run-qchem-eom.pl regression tests ($SCRIPT)"

# 1. Phase continuity after hops (5-fluorouracil cation, couplings to the active state only)
d=$(new_traj fluorouracil_active fu_active "nac_mode = active")
if replay $d fluorouracil_active; then
  n=$(nphase_bad $d/../snap 12)
  [ "$n" = "0" ] && ok "5-FU active: no sign inconsistencies over 13 steps" || bad "5-FU active: $n sign inconsistencies"
  grep -q "pair 2: aligned to stored reference from t=0.0000 (cos=-0.6993, phase=-1)" $d/../snap/1.5000.log \
    && ok "5-FU active: d32 re-aligned after the hop at 1.5 fs" || bad "5-FU active: d32 not re-aligned at 1.5 fs"
  [ -s $d/../INFO_RESTART/qchem_outputs/6.0000.out.gz ] && zcat $d/../INFO_RESTART/qchem_outputs/6.0000.out.gz | cmp -s - $d/qchem.out \
    && ok "archive: gzipped output matches qchem.out" || bad "archive: gzipped output missing or different"
else bad "5-FU active replay stopped: $(tail -1 $d/../snap/*.log | tail -1)"; fi

# 2. carry mode: pairs that are not computed keep their last value
d=$(new_traj fluorouracil_active fu_carry "nac_mode = carry")
if replay $d fluorouracil_active; then
  n=$(nphase_bad $d/../snap 12)
  [ "$n" = "0" ] && ok "5-FU carry: no sign inconsistencies" || bad "5-FU carry: $n sign inconsistencies"
  python3 - $d/../snap <<'EOF' && ok "5-FU carry: d32 at 0.5 fs equals its value at 0.0 fs" || bad "5-FU carry: d32 not carried"
import sys, numpy as np
s = sys.argv[1]
a = np.loadtxt(s + '/0.0000.nadv').reshape(3, 12, 3)[2]
b = np.loadtxt(s + '/0.5000.nadv').reshape(3, 12, 3)[2]
sys.exit(0 if np.linalg.norm(a) > 0.1 and np.allclose(a, b, atol=1e-6) else 1)
EOF
else bad "5-FU carry replay stopped"; fi

# 3. full mode: two jobs per step, every pair computed
d=$(new_traj methane_full ch4_full)
if replay $d methane_full; then
  c=$(cat $d/../snap/*.log | grep -c "(computed)")
  [ "$c" = "12" ] && ok "CH4+ full: all 3 pairs computed at all 4 steps" || bad "CH4+ full: $c computed pairs (expected 12)"
  [ "$(nphase_bad $d/../snap 5)" = "0" ] && ok "CH4+ full: no sign inconsistencies" || bad "CH4+ full: sign inconsistencies"
  n=$(grep -c '^@@@' $d/qchem.inp); t1=$(grep -m1 CC_STATE_TO_OPT $d/qchem.inp)
  [ "$n" = "1" ] && grep -q '^read' $d/qchem.inp && grep -q 'SCF_GUESS *READ' $d/qchem.inp \
    && ok "CH4+ full: input has 2 jobs, job 2 reads the geometry and orbitals" || bad "CH4+ full: unexpected input ($n separators, $t1)"
else bad "CH4+ full replay stopped: $(cat $d/../snap/*.log | tail -2)"; fi

# 4. Error handling (one step each, from methane step 0)
OUT0=$HERE/data/methane_full/outputs/0.0000.out.gz
expect_fail() { # expect_fail <label> <pattern> <tempdir> [output]
  local out=${4:-$OUT0}
  if step $3 $out 0; then bad "$1: step did not stop"
  elif grep -q "$2" $3/../snap/*.log; then ok "$1"
  else bad "$1: stopped without the expected message ($2)"; fi
}
d=$(new_traj methane_full e_sym); sed -i '/SYM_IGNORE/d' $d/JOB_NAD/qchem.inp
expect_fail "template without SYM_IGNORE is refused" "SYM_IGNORE TRUE" $d
d=$(new_traj methane_full e_key "nac_modes = full")
expect_fail "unknown keyword in qchem.par is refused" "Unknown keyword 'nac_modes'" $d
d=$(new_traj methane_full e_mode "nac_mode = all")
expect_fail "invalid nac_mode is refused" "nac_mode must be nx, full, carry or active" $d
d=$(new_traj methane_full e_trunc); zcat $OUT0 | grep -v "Thank you very much" | { mkdir -p $WORK/trunc; gzip > $WORK/trunc/0.0000.out.gz; }
expect_fail "Q-Chem job without normal termination stops the run" "did not finish normally" $d $WORK/trunc/0.0000.out.gz
d=$(new_traj methane_full e_conv); zcat $OUT0 | sed '0,/Davidson procedure converged/s//Davidson failed to converge./' | { mkdir -p $WORK/conv; gzip > $WORK/conv/0.0000.out.gz; }
expect_fail "convergence failure stops the run" "Stopping on a Q-Chem convergence failure" $d $WORK/conv/0.0000.out.gz
d=$(new_traj methane_full e_conv_ok "stop_on_unconverged = 0")
if step $d $WORK/conv/0.0000.out.gz 0 && grep -q "WARNING: Q-Chem job 1 reports" $d/../snap/0.0000.log; then ok "stop_on_unconverged = 0 continues with a warning"
else bad "stop_on_unconverged = 0 did not continue with a warning"; fi
d=$(new_traj methane_full e_njobs); zcat $OUT0 | awk '/^Running Job 2 of 2/ {exit} {print}' | { mkdir -p $WORK/onejob; gzip > $WORK/onejob/0.0000.out.gz; }
expect_fail "a missing Q-Chem job stops the run" "Expected 2 Q-Chem job(s)" $d $WORK/onejob/0.0000.out.gz
# Adiabatic step (mixed dynamics with THRES): JOB_AD template, one gradient-only job
d=$(new_traj methane_force adiab); mkdir -p $d/JOB_AD; sed -e '/CALC_NAC/d' -e 's/^METHOD .*/&\n! from JOB_AD/' $d/JOB_NAD/qchem.inp > $d/JOB_AD/qchem.inp; echo 1 > $d/type_of_dyn.out
if step $d $HERE/data/methane_force/outputs/0.0000.out.gz 0; then
  grep -q '! from JOB_AD' $d/qchem.inp && grep -q 'JOBTYPE *FORCE' $d/qchem.inp && ! grep -q '^@@@' $d/qchem.inp && [ -s $d/grad ] \
    && ok "type_of_dyn.out = 1: one gradient-only job built from JOB_AD/qchem.inp" || bad "adiabatic step: wrong input"
else bad "adiabatic step stopped: $(tail -1 $d/../snap/0.0000.log)"; fi

d=$(new_traj methane_full e_vdoth1); printf ' &shinp\n vdoth = 1\n/\n' > $d/sh.inp
expect_fail "vdoth = 1 (overlaps) is refused" "vdoth = 1 is not supported" $d
d=$(new_traj methane_full e_nonac); sed -i '/CALC_NAC/d' $d/JOB_NAD/qchem.inp
expect_fail "template without CALC_NAC is refused for vdoth = 0" "must contain 'CALC_NAC 2'" $d

# 5. Following NewtonX's coupling selection (transmomin), nac_mode not set
nadv_norms() { python3 -c "import sys,numpy as np; a=np.loadtxt(sys.argv[1]).reshape(-1,$2,3); print(' '.join('%.3f'%np.linalg.norm(v) for v in a))" $1 $2; }
d=$(new_traj methane_full nx_two); printf 'CI\n1  3  1  1\n1  3  1  2\n' > $d/transmomin
if step $d $WORK/onejob/0.0000.out.gz 0; then
  n=$(nadv_norms $d/nad_vectors 5)
  [ "$(grep -c '^@@@' $d/qchem.inp)" = "0" ] && [ "${n%% *}" = "0.000" ] \
    && ok "nx: NewtonX asks for 3-1 and 3-2 only -> 1 job, 2-1 left at zero ($n)" || bad "nx: unexpected jobs or couplings ($n)"
else bad "nx: step with restricted pairs stopped: $(tail -1 $d/../snap/0.0000.log)"; fi
d=$(new_traj methane_full nx_21); printf 'CI\n1  2  1  1\n' > $d/transmomin
if step $d $OUT0 0; then
  n=$(nadv_norms $d/nad_vectors 5); set -- $n
  grep -q 'CC_STATE_TO_OPT   \[1,1\]' $d/qchem.inp && [ "$1" != "0.000" ] && [ "$2" = "0.000" ] && [ "$3" = "0.000" ] \
    && ok "nx: NewtonX asks for 2-1 only -> second job targets state 1; 3-1 and 3-2 zeroed ($n)" || bad "nx: 2-1 only gave ($n)"
else bad "nx: step with 2-1 only stopped"; fi
d=$(new_traj methane_full nx_override "nac_mode = full"); printf 'CI\n1  3  1  1\n' > $d/transmomin
if step $d $OUT0 0; then
  n=$(nadv_norms $d/nad_vectors 5); set -- $n
  [ "$1" != "0.000" ] && [ "$2" != "0.000" ] && [ "$3" != "0.000" ] \
    && ok "nac_mode = full in qchem.par overrides NewtonX's pair list ($n)" || bad "override failed ($n)"
else bad "override step stopped"; fi

# 6. Second run after a hop: gradient taken from grad.all, Q-Chem not re-run
d=$(new_traj methane_full hop)
if step $d $OUT0 0; then
  echo "second run" > $d/which_run_is_that; sed -i 's/^\(5,0,3,\)3,/\12,/' $d/control.d
  rm -f $d/qchem.out
  ( cd $d && REPLAY_OUT=$OUT0 perl "$SCRIPT" > ../snap/second.log 2>&1 )
  want=$(sed -n '6,10p' $d/grad.all | md5sum); got=$(md5sum < $d/grad)
  [ ! -e $d/qchem.out ] && [ "$want" = "$got" ] && grep -q "Q-Chem not re-run" $d/../snap/second.log \
    && ok "second run after a hop reuses the state-2 gradient without running Q-Chem" || bad "second run did not reuse grad.all"
  # same, but the geometry changed: Q-Chem must run again and its output is archived separately
  sed -i '1s/ \(-\?[0-9]\)/ 0\1/' $d/geom; sed -i '1s/^/ /' $d/geom
  ( cd $d && REPLAY_OUT=$OUT0 perl "$SCRIPT" > ../snap/second2.log 2>&1 )
  [ -e $d/qchem.out ] && [ -s $d/../INFO_RESTART/qchem_outputs/0.0000.after_hop.out.gz ] \
    && ok "second run with a different geometry runs Q-Chem and archives it as <t>.after_hop.out.gz" || bad "second run with new geometry: $(tail -1 $d/../snap/second2.log)"
else bad "second-run test: first step failed"; fi

# 7. vdoth = 2 (time-dependent Baeck-An): one gradient-only job, no couplings
d=$(new_traj methane_force tdba); printf ' &shinp\n vdoth = 2\n/\n' > $d/sh.inp; mkdir -p $d/JOB_AD; sed '/CALC_NAC/d' $d/JOB_NAD/qchem.inp > $d/JOB_AD/qchem.inp
if step $d $HERE/data/methane_force/outputs/0.0000.out.gz 0; then
  g=$(head -1 $d/grad | awk '{printf "%.8f %.8f %.8f", $1, $2, $3}'); n=$(nadv_norms $d/nad_vectors 5)
  grep -q 'JOBTYPE *FORCE' $d/qchem.inp && ! grep -q CALC_NAC $d/qchem.inp && [ "$g" = "-0.06288588 0.00003134 -0.00001470" ] && [ "$n" = "0.000 0.000 0.000" ] \
    && ok "vdoth = 2: gradient-only input, Full Analytical Gradient read, couplings left to NewtonX" || bad "vdoth = 2: grad '$g' couplings '$n'"
else bad "vdoth = 2 step stopped: $(tail -1 $d/../snap/0.0000.log)"; fi

# 8. NewtonX wants no couplings (THRES): gradient-only job
d=$(new_traj methane_force nx_none); printf 'CI\n' > $d/transmomin
if step $d $HERE/data/methane_force/outputs/0.0000.out.gz 0; then
  grep -q 'JOBTYPE *FORCE' $d/qchem.inp && ! grep -q CALC_NAC $d/qchem.inp && grep -q "no couplings wanted, gradient only" $d/../snap/0.0000.log \
    && ok "nx: empty pair list from NewtonX -> one gradient-only job" || bad "nx: empty pair list did not give a gradient-only job"
else bad "nx empty pair list stopped: $(tail -1 $d/../snap/0.0000.log)"; fi

# 9. Q-Chem exits with an error: its reason is quoted
d=$(new_traj methane_full e_rc); mkdir -p $WORK/crash
zcat $OUT0 | awk '/CCSD T converged/ {print " CCSD iterations did not converge."; print " Q-Chem fatal error occurred in module x.C, line 26:"; print ""; print " Key '"'"'f2_oo_float'"'"' is not known."; exit} {print}' | gzip > $WORK/crash/0.0000.out.gz
if REPLAY_RC=1 step $d $WORK/crash/0.0000.out.gz 0; then bad "failing Q-Chem run did not stop the step"
elif grep -q "Q-Chem reports: CCSD iterations did not converge. | Key 'f2_oo_float' is not known." $d/../snap/0.0000.log; then ok "failing Q-Chem run stops with Q-Chem's own reason quoted"
else bad "failing Q-Chem run: reason not quoted ($(grep 'Q-Chem reports' $d/../snap/0.0000.log))"; fi

# 9b. EOM-EE state below the CCSD reference (methaniminium at 14.5 fs, C-N 2.16 A): warning
d=$(new_traj methaniminium_ee_negative ee_neg)
if step $d $HERE/data/methaniminium_ee_negative/outputs/14.5000.out.gz 29; then
  grep -q "EOM-EE state 1 lies below the CCSD reference (excitation energy -1.3560 eV)" $d/../snap/14.5000.log \
    && ok "EOM-EE state below the reference triggers a warning" || bad "no warning for an EOM-EE state below the reference"
else bad "EOM-EE negative-excitation step stopped: $(tail -1 $d/../snap/14.5000.log)"; fi

# 10. Documentation templates are the example inputs (one source of truth)
for pair in ip:methane_cation_eomip_full ea:methyl_radical_eomea ee:methaniminium_eomee sf:ethylene_eomsf; do
  t=${pair%%:*}; ex=${pair#*:}
  cmp -s $HERE/../docs/templates/$t.qchem.inp $HERE/../examples/$ex/JOB_NAD/qchem.inp \
    && ok "docs/templates/$t.qchem.inp matches examples/$ex" || bad "docs/templates/$t.qchem.inp differs from examples/$ex/JOB_NAD/qchem.inp"
done

echo "$pass passed, $fail failed"
[ $fail -eq 0 ]
