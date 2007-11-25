#!/usr/bin/perl

use strict;
use warnings;
use File::Spec;
use Set::IntSpan::Fast;

$| = 1;

my ( $test, $data )
  = map { File::Spec->catfile( qw( t perl ), $_ ) }
  qw( regexp.t re_tests );

my @wf;
open my $th, '<', $test or die "Can't read $test ($!)\n";
while ( <$th> ) {
    if ( /^ my \s+ \@will_fail \s+ = \s+ \( /x .. /^ \); /x ) {
        push @wf, $_;
    }
}
close $th;

my @will_fail = eval join '', @wf;
die $@ if $@;
my %will_fail = map { $_ => 1 } @will_fail;
my $set = Set::IntSpan::Fast->new;
$set->add( @will_fail );

open my $dh, '<', $data or die "Can't read $data ($!)\n";
while ( <$dh> ) {
    printf( "%5d: %s", $., $_ ) if $will_fail{$.};
}
close $dh;

# print join "\n", 'my @will_fail = (',
#   $set->as_string( { sep => ', ', range => ' .. ' } ), ');', '';
# use Data::Dumper;
# print Dumper( \%will_fail );
