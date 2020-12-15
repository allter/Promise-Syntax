#!/usr/bin/perl
use Test::More tests => 2;

#use lib '../lib';
#use FindBin qw();
##use lib "$FindBin::RealBin/";
#use local::lib "$FindBin::RealBin/local_lib/";

use Promise::Syntax;
use Promise::ES6;

sub promise1 { Promise::ES6->resolve( 42 ); }
sub promise2 { my $v = shift; Promise::ES6->resolve( $v + 5 ); }
sub log_promise { my $v = shift;
	#print "[$v]\n";
	Promise::ES6->resolve( undef );
}


my $result_promise = async
	await { v1 => promise1() },
	#await { die "asdf"; v2 => promise2( $_->{v1} ) },
	await { v2 => promise2( $_->{v1} ) },
	await { _ => log_promise( "acquired values: ".join( ', ', @$_{ qw(v1 v2) } ) ) },
	as { [ @$_{ qw(v1 v2) } ] }, # Values that will be ased by the $result_promise
	#as_hash,
	;

my $res = unsafeRunSync( $result_promise );
#use Data::Dumper;
#warn "res: ".Dumper( [ $res ]);
is $res->[0], '42',  'plain result';
is $res->[1], 47,  'plain result';
exit;


#####################################################

sub unsafeRunSync {
	my $promise = shift;
	my ( $is_settled, $is_resolved, $is_rejected );
	my $value;
	my $p = $promise->then(
		sub { my $res = shift; $is_settled = $is_resolved = 1; $value = $res; },
		sub { my $err = shift; $is_settled = $is_rejected = 1; $value = $err; },
	);
	while ( ! $is_settled ) {
	}

	die $value if $is_rejected;
	return $value;
};

