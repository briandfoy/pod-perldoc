package Pod::Perldoc;
use strict;
use warnings;

=encoding utf8

=head1 The build file for Pod::Perldoc

This build file is a modulino; it works as both a build script and
a module.

To build the distribution, run this file normally:

	% perl Makefile.PL

But, it's more interesting than that. You can load it with C<require>
and call C<arguments> to get the data structure it passes to
C<WriteMakefile>:

	my $package = require '/path/to/Makefile.PL';
	my $arguments = $package->arguments;

Note that C<require>-ing a file makes an entry in C<%INC> for exactly
that name. If you try to C<require> another file with the same name,
even from a different path, C<require> thinks it has already loaded
the file. As such, I recommend you always require the full path to the
file.

The return value of the C<require> is a package name (in this case,
the name of the main module. Use that to call the C<arguments> method.

Even if this distribution needs a higher version of Perl, this bit
only needs v5.8. You can play with the data structure with a primitive
Perl.

=cut

use ExtUtils::MakeMaker;
use File::Spec::Functions qw(catfile);

my $module    = __PACKAGE__;
( my $dist = $module ) =~ s/::/-/g;

my $github    = 'https://github.com/briandfoy/pod-perldoc';
my $main_file = catfile( 'lib', split /::/, "$module.pm" );

my %WriteMakefile = (
	'MIN_PERL_VERSION' => '5.008',

	'NAME'		    => $module,
	'ABSTRACT_FROM' => $main_file,
	'VERSION_FROM'	=> $main_file,
	'AUTHOR'        => 'Sean M. Burke <sburke@cpan.org>', # maintained by brian d foy, bdfoy@cpan.org

	'CONFIGURE_REQUIRES' => {
		'ExtUtils::MakeMaker'   => '6.64',
		'File::Spec::Functions' => '0',
		},

	'BUILD_REQUIRES' => {
		},

	'TEST_REQUIRES' => {
		'Test::More' => '1',
		},

	'PREREQ_PM'     => {
		'Config'                    => '0',
		'Encode'                    => '0',
		'Fcntl'                     => '0',
		'File::Spec::Functions'     => '0',
		'File::Temp'                => '0.22',
		'IO::Select'                => '0',
		'parent'                    => '0',
		'Pod::Man'                  => '2.18',
		'Pod::Simple::RTF'          => '3.16',
		'Pod::Simple::XMLOutStream' => '3.16',
		'Pod::Text'                 => '0',
		'strict'                    => '0',
		'Symbol'                    => '0',
		'Test::More'                => '0',
		'Text::ParseWords'          => '0',
		'warnings'                  => '0',
		},

	'META_MERGE' => {
		'meta-spec' => { version => 2 },
        no_index => {
            directory => 'corpus',
        	},
		resources => {
			repository => {
				type => 'git',
				url  => $github,
				web  => $github,
				},
			homepage => $github,
			},
		},

    ( ExtUtils::MakeMaker->VERSION > 6.31 ? ( 'LICENSE' => 'perl' ) : () ),

	( $ENV{PERL_CORE} ? () : (
		'MAN1PODS'  => { 'perldoc.pod' => 'blib/man1/perldoc.1' },
		'EXE_FILES' => [qw( perldoc )],
		)
	),


	($^V >= 5.008001 && $^V < 5.012 ? ( 'INSTALLDIRS'  => 'perl' ) : ()),

    test => {TESTS => 't/*.t t/*/*.t'},

	'clean' => { FILES => "$dist-*" },
	);

sub arguments { \%WriteMakefile }

do_it() unless caller;
sub do_it {
	require File::Spec;
	my $MM ='ExtUtils::MakeMaker';
	my $MM_version =
		eval{ "$MM " . $WriteMakefile{'CONFIGURE_REQUIRES'}{'ExtUtils::MakeMaker'} }
			||
		"$MM 6.64";
	eval "use $MM_version; 1" or die "Could not load $MM_version: $@";
	eval "use Test::Manifest 1.21"
		if -e File::Spec->catfile( qw(t test_manifest) );

	my $arguments = arguments();
	my $minimum_perl = $arguments->{MIN_PERL_VERSION} || '5.008';
	eval "require $minimum_perl;" or die $@;

	WriteMakefile( %$arguments );
	}

sub MY::libscan
{ # Determine things that should *not* be installed
    my($self, $path) = @_;
    return '' if $path =~ m/~/;
    $path;
}

sub MY::init_dirscan
{
    my($self) = shift;
    $self->SUPER::init_dirscan;
    # Need to force perldoc.pod to install at the top level of the lib dir:
    $self->{PM}{'perldoc.pod'} = $self->catfile($self->{INST_LIB}, 'perldoc.pod');
    return;
}

no warnings;

__PACKAGE__;
