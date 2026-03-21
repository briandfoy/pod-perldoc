use strict;
use warnings;

use lib qw(t/lib);
use TestUtils;

use Test::More;

# Hash of builtin => [output_start_regexp, output_end_regexp]
my %builtins = (
    'tr' => [ # CPAN RT#86506
        qr/\A \h+ "tr\/\*SEARCHLIST\*\/\*REPLACEMENTLIST\*\/cdsr" \R/x,
        qr/\R\s+eval "tr\/\$oldlist\/\$newlist\/, 1" or die \$\@;\R{2}\z/,
    ],
    '==' => [ # CPAN RT#126015
        qr/\A\s+Equality Operators\n/,
        qr/\n\s+if \( fc\(\$x\) eq fc\(\$y\) \) \{ \.\.\. \}\R{2}\z/,
    ],
    '<>' => [ # CPAN RT#126015
        qr/\A\s+I\/O Operators\R/,
        qr/\n\s+for its regular truth value\.\R{2}\z/,
    ]
);

for my $builtin (sort keys %builtins) {
	subtest $builtin => sub {
		my ($pid, $stdout, $stderr);

		local $ENV{PERL5LIB} = 'corpus';
		my $result = run_perldoc( '-T', '-t', '-f', $builtin );

		is length $result->{at}, 0, "open for $builtin succeeded";
		ok defined $result->{pid}, "got process ID for $builtin";

		is $result->{error}, "", "no STDERR for $builtin";

		like $result->{output}, $builtins{$builtin}->[0], "output for $builtin starts as expected";
		like $result->{output}, $builtins{$builtin}->[1], "output for $builtin ends as expected";
		};
	}

done_testing();
