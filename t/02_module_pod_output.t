
use File::Spec;
use FindBin qw($Bin);

use IPC::Open3;
use Test::More;
use Config;

# get path to perldoc exec in a hopefully platform neutral way..
my ($volume, $bindir, undef) = File::Spec->splitpath($Bin);
my $perldoc = File::Spec->catpath($volume,$bindir, File::Spec->catfile(qw(blib script perldoc)));
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

if( $> == 0 and $< == 0 ) {
	plan skip_all => 'Refusing to run under root';
}
else {
	plan tests => 7;
}

GOOD_FILE: {
	my( $stdout, $stderr );
	my $pid = eval{
		open3(\*CHLD_IN,\*CHLD_OUT1,\*CHLD_ERR1,"$^X " .$perldoc." ".$good_podfile);
	};

	is(length($@),0,"open succeeded"); # returns '' not undef
	ok(defined($pid),"got process id");

	$stdout .= $_ while <CHLD_OUT1>;
	$stderr .= $_ while <CHLD_ERR1>;

	like($stdout,qr/Look up Perl documentation/,"got expected output in STDOUT");
	#is($stderr,undef,"no output to STDERR as expected");
}


BAD_FILE: {
	my( $stdout, $stderr );
	my $pid = eval{
		open3(\*CHLD_IN,\*CHLD_OUT2,\*CHLD_ERR2,"$^X " .$perldoc." ".$bad_podfile);
	};

	is(length($@),0,"open succeeded"); # returns '' not undef
	ok(defined($pid),"got process id");

	$stdout .= $_ while <CHLD_OUT2>;
	$stderr .= $_ while <CHLD_ERR2>;

	is($stdout,undef,"no output to STDOUT as expected");
	like($stderr,qr/No documentation/,"got expected output in STDERR");
}
