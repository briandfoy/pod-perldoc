# Time-stamp: "2003-07-24 06:29:06 ADT"
require 5;
use 5.006; # Perldoc.pm currently needs at least this version
use strict;
use warnings;

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Pod::Perldoc',
    'VERSION_FROM' => 'lib/Pod/Perldoc.pm', # finds $VERSION
    'ABSTRACT'  => 'look up Perl documentation in Pod format',
    'EXE_FILES' => [qw( perldoc )],
    'PREREQ_PM' => {
		    # Are there any hard dependencies not covered here?
		    'Config' => 0,
		    'Text::ParseWords' => 0,
		    'Symbol' => 0,
		    'Fcntl' => 0,
		    'warnings' => 0,
		    'strict' => 0,
		    'File::Temp' => 0,
		    'File::Spec::Functions' => 0,
		   },
    'dist'      => { COMPRESS => 'gzip -6f', SUFFIX => 'gz', },
);

package MY;

sub libscan
{ # Determine things that should *not* be installed
    my($self, $path) = @_;
    return '' if $path =~ m/~/;
    $path;
}

__END__
