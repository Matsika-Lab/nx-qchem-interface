#!/usr/bin/env perl
# SPDX-License-Identifier: GPL-3.0-or-later
#
#====================================================================================
#
# Interface between Q-Chem (EOM-CCSD) and NewtonX 2.x
#
# Adapted from the TPP interface template by Mario Barbatti, 2021.
#
# Authors:
# Dakshitha Abeygunewardane
# Spiridoula Matsika
#
# Matsika Lab,
# Temple University, USA.
# 2025-2026.
#
#====================================================================================
#
# NewtonX calls this script once per time step inside TEMP/. It
#   1. writes the current geometry into JOB_NAD/qchem.inp,
#   2. runs Q-Chem (one or more EOM-CCSD jobs in a single input),
#   3. writes epot, grad, grad.all and nad_vectors for NewtonX,
#   4. keeps the sign of every coupling vector continuous in time.
#
# Settings are read from qchem.par in the trajectory directory (optional).
# See README.md for the list of keywords.
#
#====================================================================================
#
use strict;
use warnings;
use File::Copy;
use File::Path qw(make_path);
use Digest::MD5 qw(md5_hex);
use IO::Compress::Gzip qw(gzip $GzipError);
use lib join( '/', $ENV{"NX"}, "lib" );
use colib_perl;

# ===================================================================================
# DEFAULT SETTINGS (override any of them in qchem.par as "keyword = value")
# ===================================================================================
my %par = (
    nt                  => 4,       # threads for Q-Chem (qchem -nt)
    nac_mode            => "nx",    # nx | full | carry | active (see README)
    reuse_guess         => 1,       # start each SCF from the previous step's orbitals
    archive             => 1,       # keep each step's Q-Chem output in INFO_RESTART/qchem_outputs
    archive_interval    => 1,       # archive every n-th step
    archive_gzip        => 1,       # gzip archived outputs
    print_extracted     => 1,       # print energies, gradient and couplings to the NX log
    phase_warn          => 0.3,     # warn if |cos| against a stored phase reference is below this
    stop_on_unconverged => 1,       # stop the trajectory if Q-Chem reports a convergence failure
);
my %allowed_nac_mode = ( nx => 1, full => 1, carry => 1, active => 1 );
# ===================================================================================

my ( $mld, $mdle, $BASEDIR, $DEBUG, $JAD, $JND, $ctd, $fpar );
my ( $qchem_template, $qchem_inp, $qchem_out, $phase_ref_file, $save_name );
my ( $nat, $istep, $nstat, $nstatdyn, $ndamp, $kt, $dt, $t, $tmax, $nintc );
my ( $nxrestart, $thres, $killstat, $timekill, $prog, $lvprt, $etot_jump, $etot_drift );
my ( @symb, @zn, @x, @y, @z, @Mass );
my ( $typeofinput, $type );
my ( @epot, $mem, $retval, %progconf );
my ( $ncoup, @gx, @gy, @gz, @hx, @hy, @hz );
my ( @job_targets, @job_text, %computed_pair, %wanted_pair );
my ( $vdoth, $run_flag, $grad_only );

define_variables();
read_parameters();
write_debug1();
read_geom();
exit 0 if reuse_gradient_after_hop();
find_typeofinput();
prepare_input();
run_program();
split_jobs();
read_energy();
read_gradients();
treat_nacme();

#====================================================================================
#                                  SUBROUTINES
#====================================================================================

sub define_variables {
    $mld            = $ENV{"NX"};
    $mdle           = "run-qchem-eom.pl:";
    $qchem_template = "JOB_NAD/qchem.inp";
    $qchem_inp      = "qchem.inp";
    $qchem_out      = "qchem.out";
    $phase_ref_file = "../INFO_RESTART/nac_phase_ref";

    $BASEDIR = `pwd`;
    chomp($BASEDIR);

    $DEBUG = "DEBUG";
    $JAD   = "JOB_AD";
    $JND   = "JOB_NAD";
    $ctd   = "control.d";

    ( $nat, $istep, $nstat, $nstatdyn, $ndamp, $kt, $dt, $t, $tmax, $nintc, $mem, $nxrestart,
      $thres, $killstat, $timekill, $prog, $lvprt, $etot_jump, $etot_drift ) = load_status( $ctd, $mdle );

    %progconf = prog_config($prog);
    $fpar     = $progconf{parfile} || "qchem.par";
    $ncoup    = $nstat * ( $nstat - 1 ) / 2;

    # Q-Chem scratch folder kept between steps (orbitals only), unique per trajectory
    $save_name = "nxqc_" . substr( md5_hex($BASEDIR), 0, 12 );

    # "second run" = NewtonX calls the interface again at the same geometry after a hop
    $run_flag = read_single_value( "which_run_is_that", "" );

    # How NewtonX gets the couplings (sh.inp): 0 = coupling vectors from the interface,
    # 2 = time-dependent Baeck-An (NewtonX computes them from the energies).
    $vdoth = getkeyword( "sh.inp", "vdoth", 0 );
    if ( $vdoth != 0 && $vdoth != 2 ) {
        die "$mdle vdoth = $vdoth is not supported: Q-Chem EOM-CC provides coupling vectors (vdoth = 0) "
          . "but no wavefunction overlaps. Use vdoth = 0, or vdoth = 2 for time-dependent Baeck-An couplings.\n";
    }
}

sub read_parameters {
    #
    # Read "keyword = value" lines from qchem.par (NewtonX copies it into TEMP/).
    # A copy in JOB_NAD/ is also accepted. '#' starts a comment.
    #
    my $file;
    for my $f ( $fpar, "$JND/$fpar" ) {
        if ( -s $f ) { $file = $f; last; }
    }
    if ( defined $file ) {
        open( my $fh, '<', $file ) or die "$mdle Cannot open $file: $!";
        while ( my $l = <$fh> ) {
            $l =~ s/#.*//;
            next unless $l =~ /\S/;
            my ( $k, $v ) = $l =~ /^\s*(\w+)\s*=\s*(\S+)\s*$/
                or die "$mdle Cannot read line in $file: $l";
            $k = lc $k;
            die "$mdle Unknown keyword '$k' in $file\n" unless exists $par{$k};
            $par{$k} = lc $v;
        }
        close($fh);
    }
    die "$mdle nac_mode must be nx, full, carry or active (got '$par{nac_mode}')\n"
        unless $allowed_nac_mode{ $par{nac_mode} };
    for my $k (qw(nt archive_interval)) {
        die "$mdle $k must be a positive integer\n" unless $par{$k} =~ /^\d+$/ && $par{$k} > 0;
    }
    if ( $lvprt >= 2 ) {
        my $s = join( ", ", map {"$_=$par{$_}"} sort keys %par );
        print_STDOUT( "$mdle settings: $s\n", $istep, $kt );
    }
}

sub write_debug1 {
    if ( $lvprt >= 3 ) {
        print_STDOUT( "$mdle running in $BASEDIR\n", $istep, $kt );
        print_STDOUT( "$nat $istep $nstat $nstatdyn $ndamp $kt $dt $t $tmax \n", $istep, $kt );
        print_STDOUT( "$nintc $mem $nxrestart $thres $killstat $timekill $prog $lvprt\n", $istep, $kt );
        print_STDOUT( "$etot_jump $etot_drift\n\n", $istep, $kt );
    }
}

sub read_geom {
    #
    # Current geometry from NewtonX: symbol, Z, x, y, z (bohr), mass.
    #
    open( my $fh, '<', "geom" ) or die "$mdle Cannot open geom";
    my $ia = 0;
    while ( my $l = <$fh> ) {
        next unless $l =~ /\S/;
        $l =~ s/^\s+//;
        ( $symb[$ia], $zn[$ia], $x[$ia], $y[$ia], $z[$ia], $Mass[$ia] ) = split( /\s+/, $l );
        $ia++;
    }
    close($fh);
    die "$mdle geom has $ia atoms, control.d says $nat\n" unless $ia == $nat;
}

sub reuse_gradient_after_hop {
    #
    # After a hop NewtonX calls the interface again at the same geometry to get the
    # gradient of the new state. A coupling job already printed the gradients of all
    # states (grad.all), and they do not depend on which state the job targeted, so
    # Q-Chem does not need to run again. Returns 1 if grad was written from grad.all.
    #
    return 0 unless $run_flag eq "second run";
    return 0 unless -s "grad.all" && -s "geom.last_qchem";
    open( my $f1, '<', "geom" ) or return 0;
    open( my $f2, '<', "geom.last_qchem" ) or return 0;
    my $same = join( "", <$f1> ) eq join( "", <$f2> );
    close $f1;
    close $f2;
    return 0 unless $same;

    open( my $fh, '<', "grad.all" ) or return 0;
    my @all = grep {/\S/} <$fh>;
    close $fh;
    return 0 unless @all == $nstat * $nat;
    my @g = @all[ ( $nstatdyn - 1 ) * $nat .. $nstatdyn * $nat - 1 ];
    my $norm = 0.0;
    for (@g) { $norm += $_**2 for split; }
    return 0 unless $norm > 0.0;    # gradient of this state not available (vdoth = 2 runs)

    open( my $fo, '>', "grad" ) or die "$mdle Cannot write grad";
    print $fo @g;
    close $fo;
    print_STDOUT( "$mdle Gradient of state $nstatdyn after the hop taken from the coupling job of this step; Q-Chem not re-run.\n", $istep, $kt );
    return 1;
}

sub read_transmomin {
    #
    # Pairs NewtonX asks for this step (built from jiri.inp and THRES in control.dyn).
    # Format: a "CI" line, then "1 i 1 j" per pair. Without the file, all pairs are wanted.
    #
    my %w;
    if ( -s "transmomin" ) {
        open( my $fh, '<', "transmomin" ) or die "$mdle Cannot open transmomin";
        while ( my $l = <$fh> ) {
            my @f = split( ' ', $l );
            next unless @f == 4 && $f[1] =~ /^\d+$/ && $f[3] =~ /^\d+$/;
            my ( $i, $j ) = ( $f[1], $f[3] );
            next if $i == $j || $i > $nstat || $j > $nstat;
            $w{ pair_index( $i, $j ) } = 1;
        }
        close $fh;
    }
    else {
        $w{$_} = 1 for 0 .. $ncoup - 1;
    }
    return %w;
}

sub job_targets {
    #
    # States whose CC_STATE_TO_OPT job is run this step. Each job gives the couplings
    # between its target state and every other state, and the gradients of all states.
    # The first job always targets the active state. Then:
    #   full          jobs for all other states but one (every pair, nstat-1 jobs)
    #   nx            the fewest extra jobs that cover the pairs NewtonX asked for
    #   carry/active  no extra jobs
    # With vdoth = 2 only the active state's gradient is needed (one job, no couplings).
    #
    my @targets = ($nstatdyn);
    return @targets if $grad_only;
    if ( $par{nac_mode} eq "full" ) {
        my @others = grep { $_ != $nstatdyn } 1 .. $nstat;
        pop @others;
        push @targets, @others;
    }
    elsif ( $par{nac_mode} eq "nx" ) {
        my %left = %wanted_pair;
        my $cover = sub {
            my ($s) = @_;
            delete $left{ pair_index( $s, $_ ) } for grep { $_ != $s } 1 .. $nstat;
        };
        $cover->($nstatdyn);
        while (%left) {
            my ( $best, $nbest ) = ( 0, 0 );
            for my $s ( 1 .. $nstat ) {
                next if grep { $_ == $s } @targets;
                my $n = grep { $left{ pair_index( $s, $_ ) } } grep { $_ != $s } 1 .. $nstat;
                ( $best, $nbest ) = ( $s, $n ) if $n > $nbest;
            }
            last unless $best;
            push @targets, $best;
            $cover->($best);
        }
    }
    return @targets;
}

sub prepare_input {
    #
    # Build qchem.inp from the template: new geometry, one job per target state.
    #
    die "$mdle Q-Chem template '$qchem_template' not found\n" unless -e $qchem_template;
    open( my $fh, '<', $qchem_template ) or die "$mdle Cannot open $qchem_template: $!";
    my @tpl = <$fh>;
    close $fh;

    # The template must ignore symmetry: CC_STATE_TO_OPT [1,n] assumes a single irrep.
    my $sym_ok = grep { /^\s*SYM_IGNORE\s*=?\s*(TRUE|1)\b/i } @tpl;
    die "$mdle $qchem_template must contain 'SYM_IGNORE TRUE' (states are addressed as [1,n])\n"
        unless $sym_ok;
    my $has_rem = grep { /^\s*\$rem/i } @tpl;
    die "$mdle $qchem_template has no \$rem section\n" unless $has_rem;

    my $charge_mult;
    for my $i ( 0 .. $#tpl ) {
        if ( $tpl[$i] =~ /^\s*\$molecule/i ) { $charge_mult = $tpl[ $i + 1 ]; last; }
    }
    die "$mdle No charge/multiplicity line after \$molecule in $qchem_template\n"
        unless defined $charge_mult && $charge_mult =~ /^\s*-?\d+\s+\d+\s*$/;

    my $au2ang = units("au2ang");
    my $geom_block = $charge_mult;
    for my $i ( 0 .. $nat - 1 ) {
        $geom_block .= sprintf( "%-4s %18.10f %18.10f %18.10f\n",
            $symb[$i], $x[$i] * $au2ang, $y[$i] * $au2ang, $z[$i] * $au2ang );
    }

    # Pairs whose couplings are wanted this step
    if ( $par{nac_mode} eq "nx" ) { %wanted_pair = read_transmomin(); }
    else                          { %wanted_pair = map { $_ => 1 } 0 .. $ncoup - 1; }
    %wanted_pair = () if $grad_only;

    # NewtonX wants no couplings this step (all gaps above THRES in control.dyn):
    # a gradient-only job is enough and costs about a third less.
    my $no_pairs = ( !$grad_only && $par{nac_mode} eq "nx" && !%wanted_pair ) ? 1 : 0;
    $grad_only = 1 if $no_pairs;

    my $has_nac = grep { /^\s*CALC_NAC\b/i } @tpl;
    die "$mdle $qchem_template must contain 'CALC_NAC 2' for coupling vectors (vdoth = 0 in sh.inp)\n"
        if !$grad_only && !$has_nac;

    # The Q-Chem manuals (5.4 to 6.2) list EOM-CC couplings for EE, IP and EA only.
    if ( !$grad_only && $istep == 0 && $run_flag ne "second run" && grep { /^\s*SF_STATES\b/i } @tpl ) {
        print_STDOUT( "$mdle WARNING: EOM-SF coupling vectors are computed by Q-Chem but are not documented "
              . "(the Q-Chem manual lists EOM-CC couplings for EE, IP and EA). Check them before production use, "
              . "or use vdoth = 2 (couplings from energies).\n", $istep, $kt );
    }

    @job_targets = job_targets();
    my $have_guess = $par{reuse_guess} && -s saved_orbitals();
    if ( $par{print_extracted} || $lvprt >= 2 ) {
        my @p = map { pair_name($_) } sort { $a <=> $b } keys %wanted_pair;
        my $what = $grad_only ? ( $no_pairs ? "no couplings wanted, gradient only"
                                : $vdoth == 2 ? "gradient only (vdoth = 2, couplings from NewtonX)" : "gradient only (adiabatic step, JOB_AD)" )
                                : "couplings wanted: " . ( @p ? join( " ", @p ) : "none" );
        print_STDOUT( "$mdle nac_mode = $par{nac_mode}; " . scalar(@job_targets)
            . " Q-Chem job(s), target state(s) " . join( ",", @job_targets ) . "; $what\n", $istep, $kt );
    }

    my @jobs;
    for my $j ( 0 .. $#job_targets ) {
        my $target  = $job_targets[$j];
        my $read_mo = ( $j > 0 ) || $have_guess;
        my $out     = "";
        my $in_mol  = 0;
        my $in_rem  = 0;
        for my $line (@tpl) {
            if ( $line =~ /^\s*\$molecule/i ) {
                $in_mol = 1;
                $out .= $line;
                $out .= ( $j == 0 ) ? $geom_block : "read\n";
                next;
            }
            if ($in_mol) {
                if ( $line =~ /^\s*\$end/i ) { $in_mol = 0; $out .= $line; }
                next;
            }
            if ( $line =~ /^\s*\$rem/i ) { $in_rem = 1; $out .= $line; next; }
            if ( $in_rem && $line =~ /^\s*\$end/i ) {
                $out .= "CC_STATE_TO_OPT   [1,$target]\n";
                $out .= "SCF_GUESS         READ\n" if $read_mo;
                $out .= "JOBTYPE           FORCE\n" if $grad_only;
                $out .= $line;
                $in_rem = 0;
                next;
            }
            next if $in_rem && $line =~ /^\s*(CC_STATE_TO_OPT|SCF_GUESS)\b/i;
            next if $in_rem && $grad_only && $line =~ /^\s*(CALC_NAC|JOBTYPE)\b/i;
            $out .= $line;
        }
        push @jobs, $out;
    }

    open( my $fo, '>', $qchem_inp ) or die "$mdle Cannot create $qchem_inp: $!";
    print $fo join( "\n\@\@\@\n\n", @jobs );
    close $fo;
}

sub saved_orbitals {
    my $scr = $ENV{QCSCRATCH} || "";
    return "" unless $scr;
    return "$scr/$save_name/53.0";
}

sub find_typeofinput {
    #
    # Adiabatic (JOB_AD) or nonadiabatic (JOB_NAD) input. NewtonX uses JOB_AD for
    # adiabatic steps (type 1 in type_of_dyn.out) and whenever vdoth != 0.
    #
    my $typeout = "type_of_dyn.out";
    $type = 2;
    if ( -s $typeout ) {
        open( my $fh, '<', $typeout ) or die "$mdle Cannot open $typeout";
        my $l = <$fh>;
        close($fh);
        ($type) = $l =~ /(\d+)/ if defined $l;
        $type = 2 unless defined $type;
    }
    if    ( -e $JAD && !-e $JND ) { $typeofinput = "jad"; }
    elsif ( !-e $JAD && -e $JND ) { $typeofinput = "jnd"; }
    elsif ( -e $JAD && -e $JND )  { $typeofinput = ( $type == 1 || $vdoth != 0 ) ? "jad" : "jnd"; }
    else                          { die "$mdle Neither $JAD nor $JND exists\n"; }

    # JOB_AD (adiabatic steps, mixed dynamics with THRES, and vdoth = 2) needs only the
    # gradient of the active state: one gradient-only Q-Chem job, template from JOB_AD.
    $grad_only      = ( $typeofinput eq "jad" || $vdoth == 2 ) ? 1 : 0;
    $qchem_template = ( $typeofinput eq "jad" ) ? "$JAD/qchem.inp" : "$JND/qchem.inp";
}

sub run_program {

    my $cmd = $par{reuse_guess}
        ? "qchem -save -nt $par{nt} $qchem_inp $qchem_out $save_name > qchem.status 2>&1"
        : "qchem -nt $par{nt} $qchem_inp $qchem_out > qchem.status 2>&1";
    if ( $lvprt >= 2 ) { print_STDOUT( "$mdle $cmd\n", $istep, $kt ); }
    $retval = callprog( "", $cmd, $mdle );

    archive_output() if -e $qchem_out;
    if ( $retval != 0 ) {
        print_STDOUT( "$mdle Q-Chem returned a non-zero exit code ($retval). See TEMP/$qchem_out and qchem.status.\n", $istep, $kt );
        # Quote Q-Chem's own reason: convergence failures and the line after "fatal error"
        if ( open( my $fh, '<', $qchem_out ) ) {
            my @l = <$fh>;
            close $fh;
            my @why = grep { /(did not|failed to) converge|NOT CONVERGED/i } @l;
            for my $i ( 0 .. $#l - 2 ) {
                push @why, $l[ $i + 2 ] if $l[$i] =~ /Q-Chem fatal error/ && $l[ $i + 2 ] =~ /\S/;
            }
            print_STDOUT( "$mdle Q-Chem reports: " . join( " | ", map { s/^\s+|\s+$//gr } @why ) . "\n", $istep, $kt ) if @why;
        }
        die "$mdle Q-Chem failed\n";
    }
    prune_saved_scratch() if $par{reuse_guess};
    copy( "geom", "geom.last_qchem" ) or die "$mdle Cannot copy geom: $!";
}

sub prune_saved_scratch {
    #
    # Keep only the MO coefficients (53.0) in the saved scratch folder.
    #
    my $scr = $ENV{QCSCRATCH} or return;
    my $dir = "$scr/$save_name";
    return unless -d $dir;
    opendir( my $dh, $dir ) or return;
    for my $f ( readdir $dh ) {
        next if $f eq "." || $f eq ".." || $f eq "53.0";
        my $p = "$dir/$f";
        if ( -d $p ) { File::Path::remove_tree($p); } else { unlink $p; }
    }
    closedir $dh;
}

sub archive_output {
    return unless $par{archive} && ( $istep % $par{archive_interval} == 0 );
    my $dir = "../INFO_RESTART/qchem_outputs";
    make_path($dir) unless -d $dir;
    # A second run after a hop gets its own name so it does not replace the step's output
    my $name = ( $run_flag eq "second run" ) ? "$t.after_hop.out" : "$t.out";
    if ( $par{archive_gzip} ) {
        gzip( $qchem_out => "$dir/$name.gz" ) or die "$mdle gzip of $qchem_out failed: $GzipError\n";
    }
    else {
        copy( $qchem_out, "$dir/$name" ) or die "$mdle Cannot copy $qchem_out to $dir: $!";
    }
}

sub split_jobs {
    #
    # Split qchem.out into its jobs and check that each one finished and converged.
    #
    open( my $fh, '<', $qchem_out ) or die "$mdle Cannot open $qchem_out: $!";
    my @lines = <$fh>;
    close $fh;

    @job_text = ();
    my $cur = -1;
    for my $l (@lines) {
        if ( $l =~ /^Running Job (\d+) of (\d+)/ ) { $cur = $1 - 1; $job_text[$cur] = []; next; }
        if ( $cur < 0 ) { $cur = 0; $job_text[0] = []; }
        push @{ $job_text[$cur] }, $l;
    }
    my $njobs = scalar @job_targets;
    die "$mdle Expected $njobs Q-Chem job(s) in $qchem_out, found " . scalar(@job_text) . "\n"
        unless @job_text == $njobs;

    for my $j ( 0 .. $#job_text ) {
        my @jl = @{ $job_text[$j] };
        my $ok = grep {/Thank you very much for using Q-Chem/} @jl;
        die "$mdle Q-Chem job " . ( $j + 1 ) . " (CC_STATE_TO_OPT [1,$job_targets[$j]]) did not finish normally. See TEMP/$qchem_out\n"
            unless $ok;
        my @bad = grep { /(did not|failed to) converge|NOT CONVERGED|not converged/i } @jl;
        if (@bad) {
            chomp( my $msg = $bad[0] );
            $msg =~ s/^\s+//;
            print_STDOUT( "$mdle WARNING: Q-Chem job " . ( $j + 1 ) . " reports: $msg\n", $istep, $kt );
            die "$mdle Stopping on a Q-Chem convergence failure (set stop_on_unconverged = 0 in qchem.par to continue)\n"
                if $par{stop_on_unconverged};
        }
    }
}

sub read_energy {
    #
    # EOM state energies (hartree) from the first job.
    #
    @epot = ();
    my @jl = @{ $job_text[0] };
    for my $i ( 0 .. $#jl - 1 ) {
        next unless $jl[$i] =~ /^\s*EOM(IP|EA|EE|SF|DIP|DEA|DSF)\s+transition\s+(\d+)\//;
        my ( $kind, $n ) = ( $1, $2 );
        if ( $jl[ $i + 1 ] =~ /Total energy\s*=\s*(-?\d+\.\d+)\s+a\.u\./ ) {
            push @epot, $1;
        }
        # EOM-EE states lie above the CCSD reference. A negative excitation energy means the
        # reference is no longer the ground state (bond breaking, crossing with S0), where
        # EOM-EE is not valid; NewtonX usually stops soon after on the energy jump.
        if ( $kind eq "EE" && $jl[ $i + 1 ] =~ /Excitation energy\s*=\s*(-[\d.]+)\s*eV/ ) {
            print_STDOUT( "$mdle WARNING: EOM-EE state $n lies below the CCSD reference (excitation energy $1 eV). "
                  . "The reference is no longer the ground state, and EOM-EE cannot describe this region "
                  . "(for example bond breaking or a crossing with S0). Consider EOM-SF.\n", $istep, $kt );
        }
    }
    die "$mdle Expected at least $nstat EOM states in $qchem_out, found " . scalar(@epot) . "\n"
        if @epot < $nstat;
    $#epot = $nstat - 1;

    if ( -s "epot" ) { copy( "epot", "oldepot" ) or die "$mdle Copy failed: $!"; }
    open( my $fo, '>', "epot" ) or die "$mdle Cannot write epot";
    print $fo "$_\n" for @epot;
    close($fo);
    copy( "epot", "newepot" ) or die "$mdle Copy failed: $!";

    if ( $par{print_extracted} ) {
        print_STDOUT( "State energies (a.u.):\n", $istep, $kt );
        print_STDOUT( sprintf( "  State %d: %s\n", $_ + 1, $epot[$_] ), $istep, $kt ) for 0 .. $#epot;
        print_STDOUT( "\n", $istep, $kt );
    }
}

sub read_block {
    #
    # Read an nat x 3 table that starts 3 lines below index $i (header, labels, rule).
    #
    my ( $lines, $i ) = @_;
    my @v;
    for my $ia ( 0 .. $nat - 1 ) {
        my $l = $lines->[ $i + 3 + $ia ];
        die "$mdle Truncated table in $qchem_out\n" unless defined $l;
        my @F = split( ' ', $l );
        die "$mdle Unexpected table line in $qchem_out: $l" unless @F >= 4;
        $v[$ia] = [ @F[ 1 .. 3 ] ];
    }
    return \@v;
}

sub read_gradients {
    #
    # Gradients of all states from the G_I / G_J blocks (first occurrence of each state).
    #
    for my $ns ( 0 .. $nstat - 1 ) {
        for my $ia ( 0 .. $nat - 1 ) { $gx[$ns][$ia] = $gy[$ns][$ia] = $gz[$ns][$ia] = 0.0; }
    }
    my %have;
    for my $jl (@job_text) {
        my ( $A, $B ) = ( -1, -1 );
        for my $i ( 0 .. $#$jl ) {
            my $l = $jl->[$i];
            if ( $l =~ /State A:.*:\s+(\d+)\// ) { $A = $1; }
            if ( $l =~ /State B:.*:\s+(\d+)\// ) { $B = $1; }
            my $s;
            if    ( $l =~ /^\s*G_I,\s*a\.u\./ ) { $s = $A; }
            elsif ( $l =~ /^\s*G_J,\s*a\.u\./ ) { $s = $B; }
            next unless defined $s;
            die "$mdle Gradient block without a State A/B header\n" if $s < 1;
            next if $s > $nstat || $have{$s}++;
            my $g = read_block( $jl, $i );
            for my $ia ( 0 .. $nat - 1 ) {
                ( $gx[ $s - 1 ][$ia], $gy[ $s - 1 ][$ia], $gz[ $s - 1 ][$ia] ) = @{ $g->[$ia] };
            }
        }
    }
    if ( !$have{$nstatdyn} ) {
        # Gradient-only job (vdoth = 2): "Full Analytical Gradient" table with x, y, z as rows
        # and atoms as columns, printed in blocks of up to 6 atoms.
        my $g = read_full_gradient( $job_text[0] );
        if ($g) {
            for my $ia ( 0 .. $nat - 1 ) {
                ( $gx[ $nstatdyn - 1 ][$ia], $gy[ $nstatdyn - 1 ][$ia], $gz[ $nstatdyn - 1 ][$ia] ) = @{ $g->[$ia] };
            }
            $have{$nstatdyn} = 1;
        }
    }
    die "$mdle No gradient found for the active state $nstatdyn in $qchem_out\n" unless $have{$nstatdyn};

    open( my $f1, '>', "grad.all" ) or die "$mdle Cannot write grad.all";
    open( my $f2, '>', "grad" )     or die "$mdle Cannot write grad";
    for my $ns ( 0 .. $nstat - 1 ) {
        for my $ia ( 0 .. $nat - 1 ) {
            my $l = "$gx[$ns][$ia]  $gy[$ns][$ia]  $gz[$ns][$ia]\n";
            print $f1 $l;
            print $f2 $l if $ns == $nstatdyn - 1;
        }
    }
    close($f1);
    close($f2);

    if ( $par{print_extracted} ) {
        print_STDOUT( "Gradient of state $nstatdyn (a.u.):\n", $istep, $kt );
        for my $ia ( 0 .. $nat - 1 ) {
            print_STDOUT( sprintf( "%-4d %15.8f %15.8f %15.8f\n", $ia + 1,
                $gx[ $nstatdyn - 1 ][$ia], $gy[ $nstatdyn - 1 ][$ia], $gz[ $nstatdyn - 1 ][$ia] ), $istep, $kt );
        }
        print_STDOUT( "\n", $istep, $kt );
    }
}

sub read_full_gradient {
    #
    # Last "Full Analytical Gradient" table of a job; returns [ia] = [x,y,z] or undef.
    #
    my ($jl) = @_;
    my $start;
    for my $i ( 0 .. $#$jl ) { $start = $i if $jl->[$i] =~ /Full Analytical Gradient/; }
    return undef unless defined $start;
    my @g;
    my $i = $start + 1;
    while ( @g < $nat ) {
        my @cols = split( ' ', $jl->[$i] // "" );
        return undef unless @cols && !grep { !/^\d+$/ } @cols;    # header line of atom numbers
        for my $c ( 0 .. 2 ) {
            my @f = split( ' ', $jl->[ $i + 1 + $c ] // "" );
            return undef unless @f == @cols + 1;
            $g[ $cols[$_] - 1 ][$c] = $f[ $_ + 1 ] for 0 .. $#cols;
        }
        $i += 4;
    }
    return \@g;
}

sub pair_index {
    #
    # NewtonX lower-triangular index (0-based) of the pair (i, j), i > j.
    #
    my ( $i, $j ) = @_;
    ( $i, $j ) = ( $j, $i ) if $j > $i;
    return ( $i - 1 ) * ( $i - 2 ) / 2 + $j - 1;
}

sub pair_name {
    #
    # "j-i" label of pair index k.
    #
    my ($k) = @_;
    for my $i ( 2 .. $nstat ) {
        for my $j ( 1 .. $i - 1 ) { return "$j-$i" if pair_index( $i, $j ) == $k; }
    }
    return "?";
}

sub treat_nacme {
    return if $run_flag eq "second run";

    for my $k ( 0 .. $ncoup - 1 ) {
        for my $ia ( 0 .. $nat - 1 ) { $hx[$k][$ia] = $hy[$k][$ia] = $hz[$k][$ia] = 0.0; }
    }
    if ( -s "nad_vectors" ) { copy( "nad_vectors", "oldh" ) or die "$mdle Copy of nad_vectors to oldh failed: $!"; }
    else                    { write_vectors("oldh"); }

    if ( $grad_only ) {
        # NewtonX computes time-dependent Baeck-An couplings from the energies itself.
        %computed_pair = ();
        write_vectors("nad_vectors");
        copy( "nad_vectors", "newh" ) or die "$mdle Copy failed: $!";
        return;
    }

    read_nacme();

    my %ref = read_phase_ref();
    carry_missing_pairs( \%ref ) if $par{nac_mode} eq "carry";
    align_unreferenced_pairs( \%ref );

    write_vectors("nad_vectors");
    adjust_phase();
    copy( "nad_vectors", "newh" ) or die "$mdle Copy failed: $!";
    update_phase_ref( \%ref );
    print_nacme() if $par{print_extracted};
}

sub read_nacme {
    #
    # Couplings d_IJ = <I|d/dR J> from "NAC d^x_IJ (CI part)" blocks, stored as h_ij with
    # i > j. Q-Chem prints d_AB for State A / State B, and d_BA = -d_AB.
    # If a pair appears in more than one job, the first job's vector is used.
    #
    %computed_pair = ();
    for my $jl (@job_text) {
        my ( $A, $B ) = ( -1, -1 );
        for my $i ( 0 .. $#$jl ) {
            my $l = $jl->[$i];
            if ( $l =~ /State A:.*:\s+(\d+)\// ) { $A = $1; }
            if ( $l =~ /State B:.*:\s+(\d+)\// ) { $B = $1; }
            next unless $l =~ /^\s*NAC d\^x_IJ \(CI part\), a\.u\./;
            die "$mdle NAC block without a State A/B header\n" if $A < 1 || $B < 1;
            next if $A > $nstat || $B > $nstat;
            my $k = pair_index( $A, $B );
            next if $computed_pair{$k}++;
            my $sign = ( $A > $B ) ? 1.0 : -1.0;
            my $v = read_block( $jl, $i );
            for my $ia ( 0 .. $nat - 1 ) {
                $hx[$k][$ia] = $sign * $v->[$ia][0];
                $hy[$k][$ia] = $sign * $v->[$ia][1];
                $hz[$k][$ia] = $sign * $v->[$ia][2];
            }
        }
    }
    # Every pair that the jobs should have produced must be there
    my %expect;
    if ( $par{nac_mode} eq "nx" ) { %expect = %wanted_pair; }
    else {
        for my $s (@job_targets) { $expect{ pair_index( $s, $_ ) } = 1 for grep { $_ != $s } 1 .. $nstat; }
    }
    for my $k ( sort { $a <=> $b } keys %expect ) {
        die "$mdle Coupling " . pair_name($k) . " missing in $qchem_out\n" unless $computed_pair{$k};
    }
    # nac_mode = nx: pairs NewtonX did not ask for are zero (NewtonX coupling models)
    if ( $par{nac_mode} eq "nx" ) {
        for my $k ( keys %computed_pair ) {
            next if $wanted_pair{$k};
            delete $computed_pair{$k};
            for my $ia ( 0 .. $nat - 1 ) { $hx[$k][$ia] = $hy[$k][$ia] = $hz[$k][$ia] = 0.0; }
        }
    }
}

sub write_vectors {
    my ($file) = @_;
    open( my $fo, '>', $file ) or die "$mdle Cannot write $file";
    for my $k ( 0 .. $ncoup - 1 ) {
        for my $ia ( 0 .. $nat - 1 ) { print $fo "$hx[$k][$ia]  $hy[$k][$ia]  $hz[$k][$ia]\n"; }
    }
    close($fo);
}

sub print_nacme {
    print_STDOUT( "Nonadiabatic couplings (a.u.):\n", $istep, $kt );
    for my $i ( 2 .. $nstat ) {
        for my $j ( 1 .. $i - 1 ) {
            my $k = pair_index( $i, $j );
            my $src = $computed_pair{$k} ? "computed" : ( $par{nac_mode} eq "carry" ? "carried" : "not computed" );
            next if $src eq "not computed";
            print_STDOUT( "Coupling between state $j and state $i ($src):\n", $istep, $kt );
            for my $ia ( 0 .. $nat - 1 ) {
                print_STDOUT( sprintf( "%-4d %15.8f %15.8f %15.8f\n", $ia + 1, $hx[$k][$ia], $hy[$k][$ia], $hz[$k][$ia] ), $istep, $kt );
            }
        }
    }
    print_STDOUT( "\n", $istep, $kt );
}

sub adjust_phase {
    #
    # NewtonX escalar: flip each coupling so that it points along its value at t-dt.
    #
    copy( "nad_vectors", "newh" ) or die "$mdle Copy failed: $!";
    $retval = callprogsp( $mld, "escalar", $mdle );
    die "$mdle escalar failed\n" if $retval != 0;
    copy( "nadv", "nad_vectors" ) or die "$mdle Copy failed: $!";
    if ( $lvprt >= 3 ) { copy( "escalar.log", "../$DEBUG/." ) or die "$mdle Copy failed: $!"; }
}

#------------------------------------------------------------------------------------
# Phase reference: the last phase-corrected vector of every pair, kept across steps in
# INFO_RESTART/nac_phase_ref. escalar can only compare with t-dt; a pair that was not
# computed at t-dt (after a hop, in "active" mode) is aligned to this reference instead.
#------------------------------------------------------------------------------------

sub read_vector_file {
    my ($file) = @_;
    my @v;
    open( my $fh, '<', $file ) or die "$mdle Cannot open $file: $!";
    for my $k ( 0 .. $ncoup - 1 ) {
        for my $ia ( 0 .. $nat - 1 ) {
            my $l = <$fh>;
            die "$mdle $file is truncated\n" unless defined $l;
            $v[$k][$ia] = [ ( split( ' ', $l ) )[ 0 .. 2 ] ];
        }
    }
    close($fh);
    return @v;
}

sub pair_dot {
    my ( $u, $v ) = @_;
    my ( $uv, $uu, $vv ) = ( 0.0, 0.0, 0.0 );
    for my $ia ( 0 .. $nat - 1 ) {
        for my $c ( 0 .. 2 ) {
            $uv += $u->[$ia][$c] * $v->[$ia][$c];
            $uu += $u->[$ia][$c]**2;
            $vv += $v->[$ia][$c]**2;
        }
    }
    return ( $uv, sqrt($uu), sqrt($vv) );
}

sub current_vector {
    my ($k) = @_;
    return [ map { [ $hx[$k][$_], $hy[$k][$_], $hz[$k][$_] ] } 0 .. $nat - 1 ];
}

sub read_phase_ref {
    #
    # Format per pair: "pair <k> <t>" followed by nat lines of x y z.
    # Entries from this time or later (reused folder, restart from an earlier point) are ignored.
    #
    my %ref;
    return %ref unless -s $phase_ref_file;
    open( my $fh, '<', $phase_ref_file ) or die "$mdle Cannot open $phase_ref_file: $!";
    while ( my $l = <$fh> ) {
        next unless $l =~ /^pair\s+(\d+)\s+(\S+)/;
        my ( $k, $tref ) = ( $1, $2 );
        my @vec;
        for my $ia ( 0 .. $nat - 1 ) {
            my $d = <$fh>;
            die "$mdle $phase_ref_file is truncated\n" unless defined $d;
            $vec[$ia] = [ ( split( ' ', $d ) )[ 0 .. 2 ] ];
        }
        next if $tref > $t - 1e-6 || $k >= $ncoup;
        $ref{$k} = { t => $tref, vec => \@vec };
    }
    close($fh);
    return %ref;
}

sub carry_missing_pairs {
    #
    # nac_mode = carry: pairs not computed this step take their last phase-corrected value.
    #
    my ($ref) = @_;
    for my $k ( 0 .. $ncoup - 1 ) {
        next if $computed_pair{$k} || !exists $ref->{$k};
        for my $ia ( 0 .. $nat - 1 ) {
            ( $hx[$k][$ia], $hy[$k][$ia], $hz[$k][$ia] ) = @{ $ref->{$k}{vec}[$ia] };
        }
    }
}

sub align_unreferenced_pairs {
    my ($ref) = @_;
    my @old = read_vector_file("oldh");
    my $eps = 1e-6;
    for my $k ( 0 .. $ncoup - 1 ) {
        next unless $computed_pair{$k};
        my $cur = current_vector($k);
        my ( undef, undef, $ncur ) = pair_dot( $cur, $cur );
        my ( undef, $nold, undef ) = pair_dot( $old[$k], $old[$k] );
        next if $ncur <= $eps;
        next if $nold * $ncur > $eps;    # escalar has a t-dt reference (same test as escalar)

        if ( !exists $ref->{$k} ) {
            print_STDOUT( "$mdle Coupling pair $k: first appearance, sign kept as computed.\n", $istep, $kt )
                if $istep > 0;
            next;
        }
        my ( $dot, $nref, undef ) = pair_dot( $ref->{$k}{vec}, $cur );
        next if $nref <= $eps;
        my $cos  = $dot / ( $nref * $ncur );
        my $sign = ( $cos < 0.0 ) ? -1.0 : 1.0;
        for my $ia ( 0 .. $nat - 1 ) {
            $hx[$k][$ia] *= $sign;
            $hy[$k][$ia] *= $sign;
            $hz[$k][$ia] *= $sign;
        }
        print_STDOUT( sprintf( "$mdle Coupling pair %d: aligned to stored reference from t=%s (cos=%+.4f, phase=%+d)\n",
            $k, $ref->{$k}{t}, $cos, $sign ), $istep, $kt );
        if ( abs($cos) < $par{phase_warn} ) {
            print_STDOUT( sprintf( "$mdle WARNING: coupling pair %d is nearly orthogonal to its stored reference (|cos|=%.3f); its sign is uncertain.\n",
                $k, abs($cos) ), $istep, $kt );
        }
    }
}

sub update_phase_ref {
    #
    # Store the phase-corrected vectors (nad_vectors after escalar) of pairs computed now.
    #
    my ($ref) = @_;
    my @cur = read_vector_file("nad_vectors");
    for my $k ( 0 .. $ncoup - 1 ) {
        next unless $computed_pair{$k};
        my ( undef, $n, undef ) = pair_dot( $cur[$k], $cur[$k] );
        $ref->{$k} = { t => $t, vec => $cur[$k] } if $n > 1e-6;
        # Keep @h in sync with what NewtonX uses (for printing)
        for my $ia ( 0 .. $nat - 1 ) { ( $hx[$k][$ia], $hy[$k][$ia], $hz[$k][$ia] ) = @{ $cur[$k][$ia] }; }
    }
    for my $k ( 0 .. $ncoup - 1 ) {
        next if $computed_pair{$k};
        for my $ia ( 0 .. $nat - 1 ) { ( $hx[$k][$ia], $hy[$k][$ia], $hz[$k][$ia] ) = @{ $cur[$k][$ia] }; }
    }

    my $dir = $phase_ref_file;
    $dir =~ s{/[^/]*$}{};
    make_path($dir) unless -d $dir;
    my $tmp = "$phase_ref_file.tmp";
    open( my $fh, '>', $tmp ) or die "$mdle Cannot write $tmp: $!";
    for my $k ( sort { $a <=> $b } keys %$ref ) {
        print $fh "pair $k $ref->{$k}{t}\n";
        printf $fh "%22.12e %22.12e %22.12e\n", @{ $ref->{$k}{vec}[$_] } for 0 .. $nat - 1;
    }
    close($fh);
    rename( $tmp, $phase_ref_file ) or die "$mdle Cannot rename $tmp: $!";
}
