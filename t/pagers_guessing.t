use strict;
use warnings;
use Pod::Perldoc;
use Test::More 'tests' => 23;

{

    package MyTestObject;
    sub pagers     { defined $_[0]->{'pagers'} ? $_[0]->{'pagers'} : () }
    sub is_mswin32 { $_[0]->{'mswin32'} }
    sub is_vms     { $_[0]->{'vms'} }
    sub is_dos     { $_[0]->{'dos'} }
    sub is_amigaos { $_[0]->{'amigaos'} }
    sub is_os2     { $_[0]->{'os2'} }
    sub is_cygwin  { $_[0]->{'cygwin'} }
    sub opt_m      { $_[0]->{'opt_m'} }
    sub aside      {1}
}

my $env_pager          = 'myenvpager';
my $env_pdoc_src_pager = 'src_pager';
my $env_man_pager      = 'man_pager';
my $env_pdoc_pager     = 'perldoc_pager';
my %test_cases         = (
    'MSWin' => {
        'mswin32' => 1,
        'test'    => [ $env_pager, 'more<', 'less', 'notepad' ],
    },

    'VMS' => {
        'vms'  => 1,
        'test' => [ 'most', 'more', 'less', 'type/page' ],
    },

    'DOS' => {
        'dos'  => 1,
        'test' => [ $env_pager, 'less.exe', 'more.com<' ],
    },

    'AmigaOS' => {
        'amigaos' => 1,
        'test'    => [
            $env_pager,            '/SYS/Utilities/MultiView',
            '/SYS/Utilities/More', '/C/TYPE'
        ],
    },

    'OS2' => {
        'os2'  => 1,
        'test' => [
            "$env_pager <", 'less', 'cmd /c more <', 'more',
            'less',         'pg',   'view',          'cat'
        ],
    },

    'Unix' => {
        'unix' => 1,
        'test' => [ "$env_pager <", 'more', 'less', 'pg', 'view', 'cat' ],
    },

    'Cygwin (with less with PAGER)' => {
        'cygwin' => 1,
        'pagers' => 'less',
        'test'   =>
            [ "$env_pager <", 'less', 'more', 'less', 'pg', 'view', 'cat' ],
    },

    'Cygwin (with /usr/bin/less with PAGER)' => {
        'cygwin' => 1,
        'pagers' => '/usr/bin/less',
        'test'   => [
            "$env_pager <", '/usr/bin/less',
            'more',         'less',
            'pg',           'view',
            'cat'
        ],
    },

    # XXX: Apparently less now appears twice
    'Cygwin (with less without PAGER)' => {
        'cygwin'        => 1,
        'pagers'        => 'less',
        'test_no_pager' => 1,
        'test'          => [
            '/usr/bin/less -isrR',
            'less', 'more', 'less', 'pg', 'view', 'cat'
        ],
    },

    # XXX: Apparently less now appears twice
    'Cygwin (with /usr/bin/less without PAGER)' => {
        'cygwin'        => 1,
        'pagers'        => '/usr/bin/less',
        'test_no_pager' => 1,
        'test'          => [
            '/usr/bin/less -isrR',
            '/usr/bin/less', 'more', 'less', 'pg', 'view', 'cat'
        ],
    },

    'Cygwin (without less)' => {
        'cygwin' => 1,
        'test'   => [ "$env_pager <", 'more', 'less', 'pg', 'view', 'cat' ],
    },
);

test_with_env( { 'opt_m' => 1 }, );

test_with_env( { 'opt_m' => 0 }, );

test_less_version();

sub test_with_env {
    my ($args) = @_;
    local $ENV{'PERLDOC_SRC_PAGER'} = $env_pdoc_src_pager;
    local $ENV{'MANPAGER'}          = $env_man_pager;
    local $ENV{'PERLDOC_PAGER'}     = $env_pdoc_pager;

    foreach my $os ( sort keys %test_cases ) {
        my $perldoc = bless +{ %{ $test_cases{$os} }, %{$args} },
            'MyTestObject';
        my $test     = [ @{ $test_cases{$os}{'test'} } ];
        my $no_pager = $test_cases{$os}{'test_no_pager'};

        $no_pager
            or local $ENV{'PAGER'} = $env_pager;

        if ( $args->{'opt_m'} ) {
            unshift @{$test}, $env_pdoc_src_pager;
        } else {
            unshift @{$test}, "$env_pdoc_pager <", "$env_man_pager <";
        }

        Pod::Perldoc::pagers_guessing($perldoc);
        is_deeply(
            $perldoc->{'pagers'}, $test,
            "Correct pager ($os): " . join ', ',
            @{ $perldoc->{'pagers'} },
        );
    }
}

sub test_less_version {
    my $less_version_high = 'less 347 (GNU regular expressions)';
    my $less_version_low  = 'less 345';
    my $minimum   = '346'; # added between 340 and 346
    my @found_bins;

    foreach my $os ( sort keys %test_cases ) {
        for ( my $i = 0; $i <= $#{ $test_cases{$os}{'test'} }; $i++ ) {
            my $less_bin = $test_cases{$os}{'test'}[$i];

            $less_bin =~ /less/
                or next;

            foreach my $version_string ( $less_version_high, $less_version_low ) {
                # The less binary can have shell redirection characters
                # So we're cleaning that up and everything afterwards
                my ($less_bin_clean) = $less_bin =~ /^([^<>\s]+)/;
                my ($version)        = $version_string =~ /less (\d+)/;

                $version ge $minimum
                    and push @found_bins, [ $os, $less_bin_clean, $i ];
            }
        }
    }

    is_deeply(
        \@found_bins,
        [
            [ 'Cygwin (with /usr/bin/less with PAGER)', '/usr/bin/less', 1 ],
            [ 'Cygwin (with /usr/bin/less with PAGER)', 'less', 3 ],
            [ 'Cygwin (with /usr/bin/less without PAGER)', '/usr/bin/less', 0 ],
            [ 'Cygwin (with /usr/bin/less without PAGER)', '/usr/bin/less', 1 ],
            [ 'Cygwin (with /usr/bin/less without PAGER)', 'less', 3 ],
            [ 'Cygwin (with less with PAGER)', 'less', 1 ],
            [ 'Cygwin (with less with PAGER)', 'less', 3 ],
            [ 'Cygwin (with less without PAGER)', '/usr/bin/less', 0 ],
            [ 'Cygwin (with less without PAGER)', 'less', 1 ],
            [ 'Cygwin (with less without PAGER)', 'less', 3 ],
            [ 'Cygwin (without less)', 'less', 2 ],
            [ 'DOS', 'less.exe', 1 ],
            [ 'MSWin', 'less', 2 ],
            [ 'OS2', 'less', 1 ],
            [ 'OS2', 'less', 4 ],
            [ 'Unix', 'less', 2],
            [ 'VMS', 'less', 2 ],
        ],
        'All less versions handled without redirection and arguments',
    );
}

sub _pagers_guessing {

    # TODO: This whole subroutine needs to be rewritten. It's semi-insane
    # right now.

    my $self = shift;

    my @pagers;
    push @pagers, $self->pagers;
    $self->{'pagers'} = \@pagers;

    if ( $self->is_mswin32 ) {
        push @pagers, qw( more< less notepad );
        unshift @pagers, $ENV{PAGER} if $ENV{PAGER};
    } elsif ( $self->is_vms ) {
        push @pagers, qw( most more less type/page );
    } elsif ( $self->is_dos ) {
        push @pagers, qw( less.exe more.com< );
        unshift @pagers, $ENV{PAGER} if $ENV{PAGER};
    } elsif ( $self->is_amigaos ) {
        push @pagers,
            qw( /SYS/Utilities/MultiView /SYS/Utilities/More /C/TYPE );
        unshift @pagers, "$ENV{PAGER}" if $ENV{PAGER};
    } else {
        if ( $self->is_os2 ) {
            unshift @pagers, 'less', 'cmd /c more <';
        }
        push @pagers, qw( more less pg view cat );
        unshift @pagers, "$ENV{PAGER} <" if $ENV{PAGER};
    }

    if ( $self->is_cygwin ) {
        if ( ( $pagers[0] eq 'less' ) || ( $pagers[0] eq '/usr/bin/less' ) ) {
            unshift @pagers, '/usr/bin/less -isrR';
            unshift @pagers, $ENV{PAGER} if $ENV{PAGER};
        }
    }

    if ( $self->opt_m ) {
        unshift @pagers, "$ENV{PERLDOC_SRC_PAGER}" if $ENV{PERLDOC_SRC_PAGER};
    } else {
        unshift @pagers, "$ENV{MANPAGER} <"      if $ENV{MANPAGER};
        unshift @pagers, "$ENV{PERLDOC_PAGER} <" if $ENV{PERLDOC_PAGER};
    }

    $self->aside( "Pagers: ", ( join ", ", @pagers ) );

    return;
}

