#!/usr/bin/perl

use strict;
use warnings;
use lib 'blib/lib';
use lib 'blib/arch';

BEGIN {
    system 'make' and die "make failed: $?\n";
}

use re::engine::Oniguruma;
my $re = qr{^};

print "$re\n";
