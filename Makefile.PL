require 5.009005;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use Config;

eval 'use ExtUtils::MakeMaker::Coverage';

my @lddlflags = ( $Config{lddlflags} );

if ( $^O =~ /darwin/ ) {
    # Hack for Perl in a non-standard location on Mac OS (which it will
    # be until 5.10 ships with Mac OS).
    #
    # We need the location of perl and the directory containing
    # libperl.dylib.
    #
    # Info from: http://www.advogato.org/article/627.html
    @lddlflags = (
        '-bundle', '-bundle_loader', $Config{perl5}, '-lperl',
        "-L$Config{archlib}/CORE",
    );
}

my $oe = $Config{obj_ext};

WriteMakefile(
    ( MM->can( 'signature_target' ) ? ( SIGN => 1 ) : () ),
    NAME          => 're::engine::Oniguruma',
    AUTHOR        => 'Andy Armstrong <andy@hexten.net>',
    LICENSE       => 'perl',
    VERSION_FROM  => 'lib/re/engine/Oniguruma.pm',
    ABSTRACT_FROM => 'lib/re/engine/Oniguruma.pm',
    PL_FILES      => {},
    PREREQ_PM     => { 'Test::More' => 0, },
    dist          => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES   => 're-engine-Oniguruma-*' },
    test  => { 'TESTS' => 't/*.t t/*/*.t' },
    DIR   => ['onig'],
    INC   => '-Ionig',
    LDDLFLAGS => join( ' ', @lddlflags, "onig/*$oe", "onig/enc/*$oe" ),
);
