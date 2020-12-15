package Promise::Syntax;
use warnings;
use strict;

=head1 NAME

Promise::Syntax - Some utility syntax for Promise`s.

=cut

use base 'Exporter';
our @EXPORT = qw(
	async
	await
	as
	as_hash
);
our $VERSION = 0.7;

use Carp qw(croak);
use Storable qw(dclone); # Might change from dclone in future

=head2 async

Utility function performing chained computations possibly based on Promises or other 'then'able objects.
This mimicks async/await syntax which is available in other languages but without any extra support from the Perl language.

	my $result_promise = async
		await { v1 => promise1() },
		await { v2 => promise2( $_->{v1} ) },
		await { _ => log_promise( "acquired values: ".join( ', ', @$_{ qw(v1 v2) } ) ) },
		as { [ @$_{ qw(v1 v2) } ] }, # Values that will be returned by the $result_promise
		;

Note that you can supply pure values in the place of promises in await { }.
If there are no true promise/then`ables then the $result_promise is also a pure value.

=cut

sub async ( @ )
{
	my $as_ref = pop;
	croak "No arguments to 'async'" unless $as_ref;
	croak "Last argument to 'async' must be 'as { ... }'" unless UNIVERSAL::isa( $as_ref, 'Promise::Syntax::_As' );

	foreach ( @_ ) {
		croak "Arguments to 'async' must be await { <sym1> => promise1() }, await { <symN> => promiseN(); }, as { ... }"
			unless UNIVERSAL::isa( $_, 'Promise::Syntax::_Await' );
	}

	return _dop( {}, @_, $as_ref );
}

sub _dop
{
	local $_ = shift;
	my $code = shift;

	my $promise = $code->( $_ );
	return $promise unless @_;

	my $cb_chainer = eval { $promise->can('then') };
	unless ( $cb_chainer ) {
		unshift @_, $promise;
		goto &_dop;
	}

	my @handlers = @_;
	my $out_promise = $cb_chainer->(
		$promise,
		sub
		{
			return _dop( shift(), @handlers );
		},
	);

	return $out_promise;
}

=head2 await

Defines a chain step handler.

The code suspended in await { ... } block must return two values, a symbol and a promise.
This code also has access to $_ stash which contains symbol values from previous steps of this async computation.

If the symbol is '_' then the promise is evaluated only for its side-effects and its value is discarded.

=cut

sub await ( & ) {
	my $code = shift;

	my @caller = (caller(0))[1, 2];
	bless sub {
		my ( $symbol, $promise ) = $code->();

		die "Need <symbol> in 'await { <symbol> => <promise> }' construct "._caller_line( @caller ) unless defined $symbol;
		die "Need <promise> in 'await { $symbol => <promise> }' construct "._caller_line( @caller ) unless defined $promise;

		my $stash = $_
			or die( "No <stash> when evaluating 'await { $symbol => <promise> }' construct "._caller_line( @caller ) );
		die "'symbol' $symbol already exists in <stash> in 'await { $symbol => <promise> }' construct "._caller_line( @caller )
			if exists $stash->{ $symbol };

		my $caller_sub = (caller(1))[3];
		die "'await { $symbol => <promise> }' construct not called from 'async' construct "._caller_line( @caller )
			unless defined $caller_sub && $caller_sub =~ /::_dop$/;

		my $cb_chainer = eval { $promise->can('then') };
		unless ( $cb_chainer ) {
			return $stash if $symbol eq '_';
			my $new_stash = dclone $stash;
			$new_stash->{ $symbol } = $promise;
			return $new_stash;
		}

		return $cb_chainer->( $promise, sub {
			my $promise_result = shift;

			return $stash if $symbol eq '_';
			my $new_stash = dclone $stash;
			$new_stash->{ $symbol } = $promise_result;
			return $new_stash;
		} );
	}, 'Promise::Syntax::_Await';
}

=head2 as

This is simply a syntax for a final step of chained computations.

The code suspended in as { ... } block simply should transform the $_ stash from previous await chain handlers.

=cut

sub as ( & ) {
	my $code = shift;

	return bless $code, 'Promise::Syntax::_As';
}

=head2 as_hash

Simple shorthand to return all symbols as a hash ref for a final step of chained computations.

Currently this is simply a shorthand for:

	as { $_ }

=cut

sub as_hash () {
	return as { $_; }
}

sub _caller_line {
	my ( $file, $line ) = @_;

	return "at $file line $line\n";
}

=head1 LICENSE AND COPYRIGHT

Copyright 2020 Andrey Smirnov.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

=cut



1;
