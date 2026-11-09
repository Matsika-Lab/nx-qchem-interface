#!/usr/bin/env perl
#
# Install the Q-Chem interface into a NewtonX 2.x installation.
#
# usage: perl nx/install.pl [--nx /path/to/NX/bin] [--dry-run]
#
# What it does:
#   1. Registers Q-Chem (prog = 22.0) in $NX/lib/colib_perl.pm: prog_config,
#      check_thirdparty, read_credits, load_defaults_tpp and test_list. The added code
#      sits between "# >>> NX-QCHEM" and "# <<< NX-QCHEM" markers, so running the
#      installer again replaces it. An older hand-added prog 22 block is replaced too.
#      A time-stamped backup of colib_perl.pm is kept.
#   2. Copies run-qchem-eom.pl to $NX.
#   3. Copies the test case MD-QCHEM-EOMIP-NAD to $NX/../test-nx (run it with $NX/test-nx.pl).
#
use strict;
use warnings;
use File::Basename qw(dirname);
use File::Copy qw(copy);
use File::Path qw(make_path);
use Cwd qw(abs_path);
use POSIX qw(strftime);

my $nx  = $ENV{NX};
my $dry = 0;
while (@ARGV) {
    my $a = shift @ARGV;
    if    ( $a eq "--nx" )      { $nx = shift @ARGV; }
    elsif ( $a eq "--dry-run" ) { $dry = 1; }
    else                        { die "usage: perl nx/install.pl [--nx /path/to/NX/bin] [--dry-run]\n"; }
}
die "Set \$NX (NewtonX bin directory) or pass --nx\n" unless $nx && -d $nx;
my $here  = abs_path( dirname(__FILE__) );
my $repo  = abs_path("$here/..");
my $colib = "$nx/lib/colib_perl.pm";
die "Cannot find $colib\n" unless -f $colib;

my $M1 = "# >>> NX-QCHEM";
my $M2 = "# <<< NX-QCHEM";

my %block;
$block{prog_config} = <<'EOF';
  if (($prog >= 21.95) and ($prog < 22.05)){
      %progconf=(progname       => "qchem",
                 methodname     => "qchem-eom",
                 ic             => "n",
                 dyn            => "y",
                 hyb            => "n",
                 ip             => "n",
                 key            => sprintf("%4.1f",22.0),
                 label          => "Q-CHEM",
                 method         => "EOM-CCSD (IP, EA, EE, SF)",
                 parfile        => "qchem.par",
                 nad_exec       => "y",
                 lvprt_d        => 1,
                 vdoth_d        => 0,
                 never_state_d  => 0,
                 cio_options_d  => "NULL",
                 cisc_options_d => "NULL",
                 cprog_d        => 0,
                 progic         => "",
                 progdyn        => "run-qchem-eom.pl");
  }
EOF

$block{check_thirdparty} = <<'EOF';
     ## Q-CHEM ##
     #----------------------------------------------------------------------------
     if ($progname eq "qchem") {
       if ($type eq "dyn") {
         # Environment
         my $qcexe = `which qchem 2>/dev/null`;
         chomp($qcexe);
         if ($qcexe eq ""){exit_error("qchem is not in your PATH. Load Q-Chem and run again.",$mdle);}
         if (!defined $ENV{"QCSCRATCH"}){exit_error("\$QCSCRATCH is not defined. Set it and run again.",$mdle);}
         print_STDOUT("\tQ-Chem: $qcexe\n\tQCSCRATCH: $ENV{QCSCRATCH}\n");
         # Templates: JOB_NAD/qchem.inp (coupling steps) and/or JOB_AD/qchem.inp
         # (gradient-only steps: adiabatic or mixed dynamics, and vdoth = 2)
         my $qcvd = getkeyword("sh.inp","vdoth",0);
         if (($qcvd != 0) and ($qcvd != 2)){exit_error("vdoth = $qcvd is not available with Q-Chem EOM-CC. Use 0 (coupling vectors) or 2 (time-dependent Baeck-An).",$mdle);}
         my $qcfound = 0;
         foreach my $qcdir ($JND, $JAD){
           my $qctpl = "$qcdir/qchem.inp";
           next unless -s $qctpl;
           $qcfound++;
           open(my $qcfh, '<', $qctpl) or exit_error("Cannot open $qctpl.",$mdle);
           my $qctxt = join("", <$qcfh>);
           close($qcfh);
           if ($qctxt !~ /^\s*SYM_IGNORE\s*=?\s*(TRUE|1)\b/mi){exit_error("$qctpl must contain SYM_IGNORE TRUE.",$mdle);}
           if (($qcdir eq $JND) and ($qcvd == 0) and ($qctxt !~ /^\s*CALC_NAC\b/mi)){exit_error("$qctpl must contain CALC_NAC 2 for vdoth = 0.",$mdle);}
           if (($qcdir eq $JND) and ($qcvd == 0) and ($qctxt =~ /^\s*SF_STATES\b/mi)){print_STDOUT("\tWARNING: EOM-SF coupling vectors are not documented in the Q-Chem manual (EOM-CC couplings are listed for EE, IP and EA). Check them before production use, or use vdoth = 2.\n");}
         }
         if ($qcfound == 0){exit_error("Cannot find a Q-Chem template ($JND/qchem.inp or $JAD/qchem.inp).",$mdle);}
         # Settings (qchem.par, keyword = value)
         my @qckeys = qw(nt nac_mode reuse_guess archive archive_interval archive_gzip print_extracted phase_warn stop_on_unconverged);
         my %qcpar;
         @qcpar{@qckeys} = load_defaults_tpp($prog,"","");
         if (-s $progpar){
           open(my $qcpf, '<', $progpar) or exit_error("Cannot open $progpar.",$mdle);
           while (my $qcl = <$qcpf>){
             $qcl =~ s/#.*//;
             next unless $qcl =~ /^\s*(\w+)\s*=\s*(\S+)\s*$/;
             my ($qck,$qcv) = (lc($1),lc($2));
             if (!exists $qcpar{$qck}){exit_error("Unknown keyword '$qck' in $progpar.",$mdle);}
             $qcpar{$qck} = $qcv;
           }
           close($qcpf);
         }
         print_STDOUT("\tInterface settings ($progpar):\n");
         foreach my $qck (@qckeys){ print_STDOUT(sprintf("\t   %-20s = %s\n",$qck,$qcpar{$qck})); }
       }
     }
EOF

$block{read_credits} = <<'EOF';
    if ($code eq "qchem"){
       $value =        "-----------------------------------------------------------------------\n";
       $value = $value."NEWTON-X/Q-CHEM EOM-CCSD interface by D. Abeygunewardane and S. Matsika,\n";
       $value = $value."Temple University\n";
       $value = $value."-----------------------------------------------------------------------\n";
    }
EOF

$block{load_defaults_tpp} = <<'EOF';
    ## Q-CHEM ##
    #--------------------------------------------------------------------------
    # nt, nac_mode, reuse_guess, archive, archive_interval, archive_gzip,
    # print_extracted, phase_warn, stop_on_unconverged
    if ($progname eq "qchem"){
       return 4, "nx", 1, 1, 1, 1, 1, 0.3, 1;
    }
EOF

$block{test_list} = <<'EOF';
   # Q-CHEM EOM-IP-CCSD NAD
   $counter++;
   if ($ind == $counter){
       $progname    = "Q-CHEM         ";
       $method      = "EOM-IP-CCSD";
       $description = "Dynamics, Non-adiabatic, EOM-IP-CCSD coupling vectors";
       $dir         = "MD-QCHEM-EOMIP-NAD";
       $prog        = "$mld/moldyn.pl > moldyn.log";
       $file        = "RESULTS/dyn.out";
       $reg_exp     = "Wave function state";
       $field       = 5;
       $eps         = 1E-3;
   }
EOF

# ---------------------------------------------------------------------------------
open( my $fh, '<', $colib ) or die "Cannot read $colib: $!";
my @L = <$fh>;
close $fh;
my $orig = join( "", @L );

# 1. remove blocks from earlier installs
my @keep;
my $skip = 0;
for (@L) {
    if (/^\s*\Q$M1\E/) { $skip = 1; next; }
    if (/^\s*\Q$M2\E/) { $skip = 0; next; }
    push @keep, $_ unless $skip;
}
@L = @keep;

# 2. remove a hand-added prog 22 block in prog_config
for ( my $i = 0; $i < @L; $i++ ) {
    next unless $L[$i] =~ /^\s*if\s*\(\(\$prog\s*>=\s*21\.95\)\s*and\s*\(\$prog\s*<\s*22\.05\)\)\s*\{/;
    my $depth = 0;
    my $j     = $i;
    for ( ; $j < @L; $j++ ) {
        $depth += () = $L[$j] =~ /\{/g;
        $depth -= () = $L[$j] =~ /\}/g;
        last if $depth == 0;
    }
    splice( @L, $i, $j - $i + 1 );
    print "Removed an existing prog 22 block from prog_config.\n";
    last;
}

sub sub_range {
    my ($name) = @_;
    my ($s) = grep { $L[$_] =~ /^sub\s+\Q$name\E\b/ } 0 .. $#L;
    die "Cannot find sub $name in $colib\n" unless defined $s;
    my ($e) = grep { $L[$_] =~ /^sub\s+\w+/ } $s + 1 .. $#L;
    $e = scalar @L unless defined $e;
    return ( $s, $e );
}

sub insert_before {
    my ( $sub, $pattern, $text, $after, $last ) = @_;
    my ( $s, $e ) = sub_range($sub);
    my @hits = grep { $L[$_] =~ $pattern } $s .. $e - 1;
    die "Cannot find the insertion point in sub $sub\n" unless @hits;
    my $at = $last ? $hits[-1] : $hits[0];
    $at++ if $after;
    splice( @L, $at, 0, "$M1 (do not edit; added by nx-qchem-interface nx/install.pl)\n", $text, "$M2\n" );
}

insert_before( "prog_config",       qr/^\s*return\s+%progconf\s*;/,                 $block{prog_config},       0, 1 );
insert_before( "check_thirdparty",  qr/^\}/,                                         $block{check_thirdparty},  0, 1 );
insert_before( "read_credits",      qr/^\s*return\s+\$value\s*;/,                    $block{read_credits},      0, 1 );
insert_before( "load_defaults_tpp", qr/^\s*\$methodname\s*=\s*\$progconf\{methodname\}/, $block{load_defaults_tpp}, 1, 0 );
insert_before( "test_list",         qr/^\s*if\s*\(\$ind\s*==\s*-1\)/,                $block{test_list},         0, 1 );

my $new = join( "", @L );
if ($dry) {
    print "Dry run: colib_perl.pm would change (" . ( $new eq $orig ? "no change" : "updated" ) . ").\n";
    exit 0;
}

if ( $new ne $orig ) {
    my $bak = "$colib.bak-" . strftime( "%Y%m%d%H%M%S", localtime );
    copy( $colib, $bak ) or die "Cannot back up $colib: $!";
    open( my $fo, '>', $colib ) or die "Cannot write $colib: $!";
    print $fo $new;
    close $fo;
    my $check = `perl -I"$nx/lib" -e 'use colib_perl; my %p = prog_config(22); print \$p{progdyn}' 2>&1`;
    if ( $check ne "run-qchem-eom.pl" ) {
        copy( $bak, $colib );
        die "The patched colib_perl.pm does not load ($check). The original was restored.\n";
    }
    print "Updated $colib (backup: $bak).\n";
}
else {
    print "$colib is already up to date.\n";
}

copy( "$repo/run-qchem-eom.pl", "$nx/run-qchem-eom.pl" ) or die "Cannot copy run-qchem-eom.pl to $nx: $!";
chmod 0755, "$nx/run-qchem-eom.pl";
print "Installed $nx/run-qchem-eom.pl.\n";

my $tsrc = "$here/test-nx";
if ( -d $tsrc ) {
    my $tdst = abs_path("$nx/..") . "/test-nx";
    if ( -d $tdst ) {
        system( "cp", "-r", "$tsrc/MD-QCHEM-EOMIP-NAD", "$tdst/" ) == 0 or die "Cannot copy the test case\n";
        make_path("$tdst/STANDARD-RESULTS");
        system( "cp", "-r", "$tsrc/STANDARD-RESULTS/MD-QCHEM-EOMIP-NAD", "$tdst/STANDARD-RESULTS/" ) == 0
            or die "Cannot copy the test results\n";
        print "Installed the test case MD-QCHEM-EOMIP-NAD in $tdst.\n";
    }
}
