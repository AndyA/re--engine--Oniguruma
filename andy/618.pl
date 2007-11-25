#!/usr/bin/perl

use strict;
use warnings;
use lib 'blib/lib';
use lib 'blib/arch';

BEGIN {
    system 'make' and die "make failed: $?\n";
}

use re::engine::Oniguruma;

{
    my $subj = "a\nb\nc\n";
    while ( $subj =~ /(.)$/mg ) {
        print "got $1\n";
    }
}

{
    my $subj = "abc";
    while ( $subj =~ /(.)/mg ) {
        print "got $1\n";
    }
}

my $subject = "a\nb\nc\nd";
if ( $subject =~ /$/m ) {
    print "Match OK\n";
    my $pos = $-[0];
    print "Pos is $pos\n";
}
