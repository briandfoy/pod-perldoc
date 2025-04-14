use strict;
use warnings;

use lib qw(t/lib);
use TestUtils;

use Config;
use File::Spec;
use FindBin qw($Bin);

use Test::More;

# get path to perldoc exec in a hopefully platform neutral way..
my ($volume, $bindir, undef) = File::Spec->splitpath($Bin);
my $perldoc = perldoc_path();

my @dir = ($bindir,"lib","Pod");
my $podpath = File::Spec->catdir(@dir);
my $good_podfile = File::Spec->catpath($volume,$podpath,"Perldoc.pm");
my $bad_podfile = File::Spec->catpath($volume,$podpath,"asdfsdaf.pm");

if ($ENV{PERL_CORE}) {
    $perldoc = File::Spec->catfile('..','..','utils',
                                   ($Config{usecperl}?'c':'').'perldoc');
    @dir = ("lib","Pod");
    $good_podfile = File::Spec->catfile(@dir,"Perldoc.pm");
    $bad_podfile  = File::Spec->catfile(@dir,"asdfsdaf.pm");
}

# If the files are under /root, maybe in a container, we might not
# be able to see them after dropping privileges.
if( $^O ne 'MSWin32' and ($> == 0 or $< == 0) ) {
	plan skip_all => 'Refusing to run under root';
}
else {
	plan tests => 2;
}



subtest "good file" => sub {
	my $run = run_perldoc( $good_podfile );
	ok( $run->{success}, "$perldoc ran successfully" )
		or diag( "run failed: " . dumper($run) );

	like( $run->{output}, qr/Look up Perl documentation/, "got expected output in STDOUT" );
	};

subtest "bad file" => sub {
	my $run = run_perldoc( $bad_podfile );
	ok( $run->{success}, "$perldoc ran successfully" )
		or diag( "run failed: " . dumper($run) );

	is( $run->{output}, '', "no output to STDOUT is empty" );
	like( $run->{error}, qr/No documentation/, "got expected output in STDERR" );
	};

done_testing();
