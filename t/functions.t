use strict;
use warnings;

use Test::More;

use FindBin qw($Bin);

eval "use Test::Output 1.03";
plan skip_all => 'Test::Output 1.03 or higher not installed.' if $@;

stdout_like(sub {system($Bin."/../perldoc Test::Output")},qr/Utilities to test STDOUT/);
#stderr_like(sub {system($Bin."/../perldoc -f dasfsadfsdaf")},qr/No documentation for perl function/);

done_testing();
