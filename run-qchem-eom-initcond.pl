#!/usr/bin/env perl
# SPDX-License-Identifier: GPL-3.0-or-later
#
#====================================================================================
#
# Q-Chem EOM-CCSD interface for NewtonX initial conditions and spectra (initcond.pl)
#
# Authors: Dakshitha Abeygunewardane, Spiridoula Matsika
# Matsika Lab, Temple University, USA. 2026.
# Refactored and improved with Claude Code (Anthropic) using the Claude Opus 5.5
# model; see the AI assistance note in README.md.
#
#====================================================================================
#
# NewtonX calls this script for every sampled geometry, inside TEMP/, with the
# contents of JOB_AD/ copied there. It runs one Q-Chem single point from
# JOB_AD/qchem.inp and writes, for each state ifs = 2 .. nfs:
#   epot.<ifs>  (epot0.<ifs> at the reference geometry): E(state 1) and E(state ifs), hartree
#   oos.<ifs>   intensity of the transition 1 -> ifs
#
# State numbering for NewtonX (state 1 is the initial state of the transition):
#   EOM-EE, EOM-IP, EOM-EA  state 1 = CCSD reference, state k+1 = EOM state k
#   EOM-SF                  state k = EOM-SF state k (state 1 is the ground state)
# Intensities:
#   EOM-EE  oscillator strength reference -> EOM state (CC_TRANS_PROP 1)
#   EOM-SF  oscillator strength SF state 1 -> SF state k (CC_STATE_TO_OPT [1,1], CC_TRANS_PROP 1)
#   EOM-IP, EOM-EA  product of the left and right Dyson orbital norms (CC_DO_DYSON),
#           the EOM-CC counterpart of the squared Dyson norm in NewtonX's DO-norm approach
#
#====================================================================================
#
use strict;
use warnings;
use lib join( '/', $ENV{"NX"}, "lib" );
use colib_perl;

my $mdle     = "run-qchem-eom-initcond.pl:";
my $template = "JOB_AD/qchem.inp";
my $qcinp    = "qchem_ic.inp";
my $qcout    = "qchem_ic.out";

my $nis     = getkeyword( "initqp_input", "nis",     1 );
my $nfs     = getkeyword( "initqp_input", "nfs",     2 );
my $lvprt   = getkeyword( "initqp_input", "lvprt",   1 );
my $ics_flg = getkeyword( "initqp_input", "ics_flg", "n" );
$ics_flg =~ s/["'\s]//g;
my $epotf = ( -e "zero" ) ? "epot0" : "epot";

die "$mdle ics_flg = y (initial conditions for multiple states with orbitals) is not supported with Q-Chem\n"
    if lc($ics_flg) eq "y";
die "$mdle nis = $nis: only transitions from state 1 are supported (set nis = 1 in initqp_input)\n"
    unless $nis == 1;
die "$mdle Q-Chem template $template not found (initial conditions use JOB_AD/qchem.inp)\n"
    unless -s $template;

# Threads from qchem.par (trajectory folder or JOB_AD), default 4
my $nt = 4;
for my $f ( "qchem.par", "JOB_AD/qchem.par", "../qchem.par" ) {
    next unless -s $f;
    open( my $fh, '<', $f ) or next;
    while (<$fh>) { s/#.*//; $nt = $1 if /^\s*nt\s*=\s*(\d+)\s*$/i; }
    close $fh;
    last;
}

# ---------------------------------------------------------------------------------
# Template and method
# ---------------------------------------------------------------------------------
open( my $tf, '<', $template ) or die "$mdle Cannot open $template";
my @tpl = <$tf>;
close $tf;
my ( $kind, $nroots );
for (@tpl) {
    if (/^\s*(IP|EA|EE|SF)_STATES\s*=?\s*\[\s*(\d+)/i) { ( $kind, $nroots ) = ( uc $1, $2 ); last; }
}
die "$mdle $template has no IP_STATES, EA_STATES, EE_STATES or SF_STATES\n" unless $kind;
die "$mdle $template must contain SYM_IGNORE TRUE\n" unless grep { /^\s*SYM_IGNORE\s*=?\s*(TRUE|1)\b/i } @tpl;

my $needed = ( $kind eq "SF" ) ? $nfs : $nfs - 1;
die "$mdle nfs = $nfs needs $needed ${kind}_STATES, but $template asks for $nroots\n" if $nroots < $needed;

my %extra = (
    EE => ["CC_TRANS_PROP     1\n"],
    SF => [ "CC_STATE_TO_OPT   [1,1]\n", "CC_TRANS_PROP     1\n" ],
    IP => ["CC_DO_DYSON       TRUE\n"],
    EA => ["CC_DO_DYSON       TRUE\n"],
);

# ---------------------------------------------------------------------------------
# Geometry (NewtonX geom: symbol, Z, x, y, z in bohr, mass)
# ---------------------------------------------------------------------------------
my $au2ang = units("au2ang");
open( my $gm, '<', "geom" ) or die "$mdle Cannot open geom";
my $geo = "";
while (<$gm>) {
    next unless /\S/;
    my @f = split;
    $geo .= sprintf( "%-4s %18.10f %18.10f %18.10f\n", $f[0], $f[2] * $au2ang, $f[3] * $au2ang, $f[4] * $au2ang );
}
close $gm;

# ---------------------------------------------------------------------------------
# Q-Chem input: template with the new geometry, couplings and gradients removed,
# transition properties or Dyson orbitals added
# ---------------------------------------------------------------------------------
my ( $out, $in_mol, $in_rem, $cm ) = ( "", 0, 0, undef );
for my $i ( 0 .. $#tpl ) {
    my $l = $tpl[$i];
    if ( $l =~ /^\s*\$molecule/i ) {
        $in_mol = 1;
        $cm     = $tpl[ $i + 1 ];
        die "$mdle No charge/multiplicity line after \$molecule in $template\n"
            unless defined $cm && $cm =~ /^\s*-?\d+\s+\d+\s*$/;
        $out .= $l . $cm . $geo;
        next;
    }
    if ($in_mol) {
        if ( $l =~ /^\s*\$end/i ) { $in_mol = 0; $out .= $l; }
        next;
    }
    if ( $l =~ /^\s*\$rem/i ) { $in_rem = 1; $out .= $l; next; }
    if ( $in_rem && $l =~ /^\s*\$end/i ) {
        $out .= join( "", @{ $extra{$kind} } ) . $l;
        $in_rem = 0;
        next;
    }
    next if $in_rem && $l =~ /^\s*(CALC_NAC|CC_STATE_TO_OPT|JOBTYPE|SCF_GUESS|CC_TRANS_PROP|CC_DO_DYSON)\b/i;
    $out .= $l;
}
open( my $fo, '>', $qcinp ) or die "$mdle Cannot write $qcinp";
print $fo $out;
close $fo;

my $retval = callprog( "", "qchem -nt $nt $qcinp $qcout > qchem_ic.status 2>&1", $mdle );
die "$mdle Q-Chem failed (exit $retval); see TEMP/$qcout\n" if $retval != 0;

# ---------------------------------------------------------------------------------
# Read energies and intensities
# ---------------------------------------------------------------------------------
open( my $fq, '<', $qcout ) or die "$mdle Cannot open $qcout";
my @L = <$fq>;
close $fq;
die "$mdle Q-Chem did not finish normally; see TEMP/$qcout\n" unless grep {/Thank you very much for using Q-Chem/} @L;

my ( $eref, @eom, %osc, %dysL, %dysR );
my ( $A, $B ) = ( -1, -1 );
for my $i ( 0 .. $#L ) {
    my $l = $L[$i];
    $eref = $1 if !defined $eref && $l =~ /CCSD total energy\s*=\s*(-?\d+\.\d+)/;
    if ( $l =~ /^\s*EOM$kind\s+transition\s+(\d+)\// ) {
        my $n = $1;
        $eom[ $n - 1 ] = $1 if $L[ $i + 1 ] =~ /Total energy\s*=\s*(-?\d+\.\d+)\s+a\.u\./;
    }
    if ( $l =~ /State A:\s*(\S+?):\s*(\d+)\// ) { $A = ( $1 eq "ccsd" ) ? 0 : $2; }
    if ( $l =~ /State B:\s*\S+?:\s*(\d+)\// )   { $B = $1; }
    # Q-Chem lists the pair in either order (EOM-EA prints the EOM state as State A)
    my $pair = join( "-", sort { $a <=> $b } ( $A, $B ) );
    $osc{$pair}  = $1 if $l =~ /Oscillator strength \(a\.u\.\):\s*(-?[\d.]+)/;
    $dysL{$pair} = $1 if $l =~ /Left Dyson orbital norm is\s*([\d.]+)/;
    $dysR{$pair} = $1 if $l =~ /Right Dyson orbital norm is\s*([\d.]+)/;
}
die "$mdle Found " . scalar( grep {defined} @eom ) . " EOM-$kind states, need $needed\n"
    if scalar( grep {defined} @eom[ 0 .. $needed - 1 ] ) < $needed;

# NewtonX state energies E[1..nfs] and intensities I[2..nfs]
my ( @E, @I );
if ( $kind eq "SF" ) {
    @E[ 1 .. $nfs ] = @eom[ 0 .. $nfs - 1 ];
    for my $k ( 2 .. $nfs ) { $I[$k] = $osc{"1-$k"}; }
}
else {
    die "$mdle CCSD reference energy not found in $qcout\n" unless defined $eref;
    $E[1] = $eref;
    for my $k ( 2 .. $nfs ) {
        $E[$k] = $eom[ $k - 2 ];
        my $key = "0-" . ( $k - 1 );
        $I[$k] = ( $kind eq "EE" ) ? $osc{$key}
               : ( defined $dysL{$key} && defined $dysR{$key} ) ? $dysL{$key} * $dysR{$key}
               : undef;
    }
}
for my $k ( 2 .. $nfs ) {
    die "$mdle No intensity for the transition 1 -> $k in $qcout\n" unless defined $I[$k];
    $I[$k] = abs( $I[$k] ) + 0.0;    # Q-Chem prints -0.000000 for spin-forbidden SF transitions
    $I[$k] = 0.0 if $I[$k] == 0;
    open( my $ep, '>', "$epotf.$k" ) or die "$mdle Cannot write $epotf.$k";
    print $ep "$E[1]\n$E[$k]\n";
    close $ep;
    open( my $os, '>', "oos.$k" ) or die "$mdle Cannot write oos.$k";
    print $os "$I[$k]\n";
    close $os;
}

# State information for the NewtonX log
my $au2ev = units("au2ev");
my $what  = ( $kind eq "EE" || $kind eq "SF" ) ? "oscillator strength" : "Dyson norm L*R";
print_STDOUT("\n[STATE INFORMATION] EOM-$kind-CCSD (Q-Chem)\n");
print_STDOUT( sprintf( "  %-6s %18s %12s   %s\n", "state", "energy (a.u.)", "dE (eV)", $what ) );
print_STDOUT( sprintf( "  %-6d %18.8f\n", 1, $E[1] ) );
for my $k ( 2 .. $nfs ) {
    print_STDOUT( sprintf( "  %-6d %18.8f %12.4f   %.6f\n", $k, $E[$k], ( $E[$k] - $E[1] ) * $au2ev, $I[$k] ) );
}
print_STDOUT("[END STATE INFORMATION]\n");
exit 0;
