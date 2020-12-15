#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Promise::Syntax' ) || print "Bail out!\n";
}

diag( "Testing Promise::Syntax $Promise::Syntax::VERSION, Perl $], $^X" );
