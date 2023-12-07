package TestUtils;
use strict;
use warnings;

use Data::Dumper;
use Exporter qw(import);
use File::Spec::Functions qw(catfile);
use IPC::Open3;
use Symbol;

our @EXPORT = qw(
	dumper
	perldoc_path
	run_perldoc
	);

use Data::Dumper;
sub dumper { Data::Dumper->new([@_])->Indent(1)->Sortkeys(1)->Terse(1)->Useqq(1)->Dump }

sub perldoc_path {
	catfile( qw(blib script perldoc) );
	}

sub run_perldoc {
	my( @args ) = @_;

	my( $stdout, $stderr );
	my( $child_in, $child_out, $child_err );
	my $pid = eval{
		open3(
			$child_in, $child_out, $child_err = Symbol::gensym(),
			$^X, perldoc_path(), @args
			);
		};
	my $at = $@;
	my $success = length($at) == 0;

	return unless $pid;
	waitpid( $pid, 0 );

	my $output = do { local $/; <$child_out> };
	my $error  = do { local $/; <$child_err> };

	my %hash = (
		output  => $output,
		error   => $error,
		exit    => $? >> 8,
		success => $success,
		pid     => $pid,
		args    => [ @args ],
		perldoc => perldoc_path(),
		perl    => $^X,
		at      => $at,
		);

	return \%hash;
	}

__PACKAGE__
