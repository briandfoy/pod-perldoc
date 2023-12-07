use strict;
use warnings;

use Test::More 1;

use lib qw(t/lib);
use TestUtils;

use HTTP::Tiny;

our $url = 'https://fastapi.metacpan.org/source/MALLEN/Pod-Perldoc-3.28/lib/Pod/Perldoc.pm';

my $fetched_url = 1;
my $found_perldoc = 1;

my $perldoc = perldoc_path();

subtest sanity => sub {
	subtest perldoc => sub {
		ok( -e perldoc_path(), "found $perldoc" );
		};

	subtest internet => sub {
		my $response = HTTP::Tiny->new->get($url);
		unless( $response->{success} ) {
			pass();
			diag("Could not fetch [$url]\nGot status $response->{success}");
			$fetched_url = 0;
			return;
			}
		ok( $response->{success}, "Fetched $url" );
		like( $response->{content}, qr/^=head1 NAME/m, "Looks like Pod" );
		};
	};

unless( $found_perldoc ) {
	# Hey, are you running this test in the repo instead of automated testing?
	diag( "Did not find $perldoc. Perhaps you need to run `perl Makefile && make`" );
	done_testing;
	exit;
	}

unless( $fetched_url ) {
	# Maybe you are offline, or the server is having problems.
	diag( "Did not fetch test file, so not testing." );
	done_testing;
	exit;
	}

subtest 'fetch https' => sub {
	my $run = run_perldoc( $url );
	ok( $run->{success}, "$perldoc ran successfully" )
		or diag( "run failed: " . dumper($run) );
	test_translation( $run->{output} );
	};

subtest 'fetch https with redirection' => sub {
	local $url = $url;
	$url =~ s/\Ahttps/http/;
	my $run = run_perldoc( $url );
	ok( $run->{success}, "$perldoc ran successfully" )
		or diag( "run failed: " . dumper($run) );
	test_translation( $run->{output} );
	};

sub test_translation {
	my( $pod ) = @_;
	subtest 'check pod' => sub {
		like $pod, qr/^(?:\x1B\[1m)?NAME(?:\x1B\[0m)?\R+^\h*Pod::Perldoc/m, 'Found NAME header'
		};
	}

done_testing;
