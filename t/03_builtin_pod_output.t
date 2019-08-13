
use File::Spec;
use FindBin qw($Bin);

use IPC::Open3;
use Test::More;
use Config;

my $pid = undef;
my $stdout = undef;
my $stderr = undef;

# get path to perldoc exec in a hopefully platform neutral way..
my ($volume, $bindir, undef) = File::Spec->splitpath($Bin);
my $perldoc = File::Spec->catpath($volume,$bindir, File::Spec->catfile(qw(blib script perldoc)));
if ($ENV{PERL_CORE}) {
    $perldoc = File::Spec->catfile('..','..','utils',
                                   ($Config{usecperl}?'c':'').'perldoc');
}

# Hash of builtin => [output_start_regexp, output_end_regexp]
my %builtins = (
    'tr' => [ # CPAN RT#86506
        qr/\A\s+"tr\/\*SEARCHLIST\*\/\*REPLACEMENTLIST\*\/cdsr"\n/,
        qr/\n\s+eval "tr\/\$oldlist\/\$newlist\/, 1" or die \$\@;\n\n\z/
    ],
    '==' => [ # CPAN RT#126015
        qr/\A\s+Equality Operators\n/,
        qr/\n\s+if \( fc\(\$x\) eq fc\(\$y\) \) \{ \.\.\. \}\n\n\z/
    ],
    '<>' => [ # CPAN RT#126015
        qr/\A\s+I\/O Operators\n/,
        qr/\n\s+for its regular truth value\.\n\n\z/
    ]
);

plan tests => 5 * scalar keys %builtins;

for my $builtin (sort keys %builtins) {
    my ($pid, $stdout, $stderr);

    eval {
        $pid = open3(\*CHLD_IN, \*CHLD_OUT1, \*CHLD_ERR1,
            $^X, '-Mblib', '-Icorpus', $perldoc, '-T', '-t', '-f', $builtin);
    };

    is(length($@), 0, "open for $builtin succeeded"); # returns '' not undef
    ok(defined($pid), "got process ID for $builtin");

    # gather STDERR
    while(<CHLD_ERR1>){
        $stderr .= $_;
    }

    # check STDERR
    is($stderr, undef, "no STDERR for $builtin");

    # gather STDOUT
    while(<CHLD_OUT1>){
        $stdout .= $_;
    }

    # check STDOUT
    like($stdout, $builtins{$builtin}->[0], "output for $builtin starts as expected");
    like($stdout, $builtins{$builtin}->[1], "output for $builtin ends as expected");
}

