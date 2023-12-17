use strict;
use warnings;
use Test::More 'tests' => 17;
use Pod::Perldoc;

# Version Tested | Tested Against | Description
my @test_cases = (
    [ '2.0.0', '1.0.0',         'Increment in Major Version'              ],
    [ '1.0.0', '0.1.0',         'Major Version Zero'                      ],
    [ '1.2.0', '1.1.0',         'Increment in Minor Version'              ],
    [ '2.1.0', '1.5.0',         'Minor Version Changes with Same Major'   ],
    [ '1.0.2', '1.0.1',         'Increment in Patch Version'              ],
    [ '1.3.0', '1.2.3',         'Patch Version with Same Major and Minor' ],
    [ '1.1.0', '1.0.999999999', 'Very Large Numbers'                      ],
);

# more use-cases
# '1.0.0',         '1.0.0-alpha',    'Pre-release Versions',
# '1.0.0+build.2', '1.0.0+build.1',  'Build Metadata',
# '1.a.0',         'Valid versions', 'Non-Numeric Parts',

foreach my $test (@test_cases) {
    ok( Pod::Perldoc::semver_ge( $test->[0],  $test->[1] ), $test->[2] );
    ok( !Pod::Perldoc::semver_ge( $test->[1], $test->[0] ), $test->[2] );
}

my $equal_ver = '1.2.3';
ok( Pod::Perldoc::semver_ge( $equal_ver, $equal_ver ), 'Equal Versions' );
ok(
    Pod::Perldoc::semver_ge( $equal_ver, '01.02.03' ),
    'Equal Versions (Zero Padding)',
);

ok(
    Pod::Perldoc::semver_ge( '01.02.03', $equal_ver ),
    'Equal Versions (Zero Padding) in reverse'
);
