use strict;
use warnings;
use Test::More;

use Pod::Perldoc ();
use Pod::Perldoc::ToTerm ();

{
    package Local::Perldoc;
    use parent 'Pod::Perldoc';

    sub new {
        return bless { pagers => [], executables => {}, _fake_cmd => {} }, shift;
    }

    sub is_mswin32 { 0 }
    sub is_dos     { 0 }
    sub is_amigaos { 0 }

    sub set_fake_command {
        my ( $self, $pattern, $output ) = @_;
        $self->{_fake_cmd}{$pattern} = $output;
        return;
    }

    sub _run_command {
        my ( $self, $command ) = @_;
        foreach my $pattern ( keys %{ $self->{_fake_cmd} } ) {
            return $self->{_fake_cmd}{$pattern} if $command =~ /$pattern/;
        }
        return '';
    }
}

sub make_perldoc {
    my (%args) = @_;
    my $perldoc = Local::Perldoc->new;
    $perldoc->{pagers} = $args{pagers} || [];
    $perldoc->{executables}{nroffer} = $args{nroffer};
    return $perldoc;
}

sub with_fake_versions {
    my (%args) = @_;
    my $perldoc = $args{perldoc};
    my $code    = $args{code};

    $perldoc->set_fake_command(qr/groff/, $args{groff});
    $perldoc->set_fake_command(qr/less/, $args{less});

    return $code->();
}

{
    local $ENV{TERM} = 'xterm-256color';
    local $ENV{PAGER};
    local $ENV{PERLDOC_PAGER};
    local $ENV{LESS};
    my $perldoc = make_perldoc(
        pagers  => ['less'],
        nroffer => 'groff',
    );
    my $formatter = with_fake_versions(
        perldoc => $perldoc,
        groff => "groff version 1.21\n",
        less  => "less 350\n",
        code  => sub { Pod::Perldoc::choose_formatter($perldoc) },
    );
    is( $formatter, 'man', 'prefers ToMan with new groff' );
    ok( $perldoc->can_use_toman, 'can_use_toman returns true with new groff' );
}

{
    local $ENV{TERM} = 'xterm';
    local $ENV{PAGER};
    local $ENV{PERLDOC_PAGER};
    local $ENV{LESS};
    my $perldoc = make_perldoc(
        pagers  => ['less'],
        nroffer => 'groff',
    );
    my $formatter = with_fake_versions(
        perldoc => $perldoc,
        groff => "groff version 1.19\n",
        less  => "less 346\n",
        code  => sub { Pod::Perldoc::choose_formatter($perldoc) },
    );
    is( $formatter, 'term', 'uses ToTerm with old groff and new less' );
    ok( $perldoc->can_use_toterm, 'can_use_toterm returns true with new less' );
}

{
    local $ENV{TERM} = 'xterm';
    local $ENV{PAGER};
    local $ENV{PERLDOC_PAGER};
    local $ENV{LESS};
    my $perldoc = make_perldoc(
        pagers  => ['less'],
        nroffer => 'groff',
    );
    my $formatter = with_fake_versions(
        perldoc => $perldoc,
        groff => "groff version 1.19\n",
        less  => "less 345\n",
        code  => sub { Pod::Perldoc::choose_formatter($perldoc) },
    );
    is( $formatter, undef, 'falls back when less is too old' );
    ok( !$perldoc->can_use_toterm, 'can_use_toterm returns false with old less' );
}

{
    local $ENV{TERM} = 'dumb';
    local $ENV{PAGER};
    local $ENV{PERLDOC_PAGER};
    local $ENV{LESS};
    my $perldoc = make_perldoc(
        pagers  => ['less'],
        nroffer => 'groff',
    );
    my $formatter = with_fake_versions(
        perldoc => $perldoc,
        groff => "groff version 1.21\n",
        less  => "less 350\n",
        code  => sub { Pod::Perldoc::choose_formatter($perldoc) },
    );
    is( $formatter, 'man', 'uses ToMan even for dumb terminals' );
    ok( $perldoc->can_use_toman, 'can_use_toman is independent of TERM' );
}

{
    local $ENV{TERM} = 'xterm';
    local $ENV{PAGER} = 'more';
    local $ENV{PERLDOC_PAGER};
    local $ENV{LESS};
    my $perldoc = make_perldoc(
        pagers  => ['less'],
        nroffer => 'groff',
    );
    my $formatter = with_fake_versions(
        perldoc => $perldoc,
        groff => "groff version 1.19\n",
        less  => "less 350\n",
        code  => sub { Pod::Perldoc::choose_formatter($perldoc) },
    );
    is( $formatter, undef, 'rejects ToTerm when explicit pager is not less' );
    ok( !$perldoc->can_use_toterm, 'explicit non-less pager blocks ToTerm' );
}

{
    local $ENV{TERM} = 'xterm';
    local $ENV{PAGER} = 'less | cat';
    local $ENV{PERLDOC_PAGER};
    local $ENV{LESS};
    my $perldoc = make_perldoc(
        pagers  => ['less'],
        nroffer => 'groff',
    );
    my $formatter = with_fake_versions(
        perldoc => $perldoc,
        groff => "groff version 1.19\n",
        less  => "less 350\n",
        code  => sub { Pod::Perldoc::choose_formatter($perldoc) },
    );
    is( $formatter, undef, 'rejects ToTerm when pager is complex' );
    ok( !$perldoc->can_use_toterm, 'complex explicit pager blocks ToTerm' );
}

{
    my $perldoc = make_perldoc();
    subtest '_can_pass_r_safely cases' => sub {
        local $ENV{LESS};
        ok( $perldoc->_can_pass_r_safely('-R'), 'accepts explicit -R in args' );

        local $ENV{LESS} = 'FRSX';
        ok( $perldoc->_can_pass_r_safely(' -R '), 'accepts -R in args even when LESS set' );

        local $ENV{LESS};
        ok( $perldoc->_can_pass_r_safely(''), 'accepts when LESS is undefined' );

        local $ENV{LESS} = '-R';
        ok( $perldoc->_can_pass_r_safely(''), 'accepts when LESS already has -R' );

        local $ENV{LESS} = 'FRSX';
        ok( !$perldoc->_can_pass_r_safely(''), 'rejects when LESS is set without -R' );
    };
}

{
    my $perldoc = make_perldoc();
    subtest 'terminal_accepts_ansi whitelist' => sub {
        local $ENV{TERM} = 'xterm';
        ok( $perldoc->terminal_accepts_ansi, 'xterm allowed' );

        local $ENV{TERM} = 'xterm-256color';
        ok( $perldoc->terminal_accepts_ansi, 'xterm-256color allowed' );

        local $ENV{TERM} = 'screen-256color';
        ok( $perldoc->terminal_accepts_ansi, 'screen allowed' );

        local $ENV{TERM} = 'tmux-256color';
        ok( $perldoc->terminal_accepts_ansi, 'tmux allowed' );

        local $ENV{TERM} = 'vt100';
        ok( $perldoc->terminal_accepts_ansi, 'vt100 allowed' );

        local $ENV{TERM} = 'linux';
        ok( $perldoc->terminal_accepts_ansi, 'linux allowed' );

        local $ENV{TERM} = 'ansi';
        ok( $perldoc->terminal_accepts_ansi, 'ansi allowed' );

        local $ENV{TERM} = 'dumb';
        ok( !$perldoc->terminal_accepts_ansi, 'dumb rejected' );
    };
}

{
    my $perldoc = make_perldoc();
    subtest 'explicit pager precedence' => sub {
        local $ENV{PERLDOC_PAGER} = 'less';
        local $ENV{PAGER} = 'more';
        is( $perldoc->_explicit_pager_command, 'less', 'PERLDOC_PAGER wins' );

        local $ENV{PERLDOC_PAGER};
        local $ENV{PAGER} = 'less';
        is( $perldoc->_explicit_pager_command, 'less', 'PAGER used when PERLDOC_PAGER missing' );

        local $ENV{PERLDOC_PAGER};
        local $ENV{PAGER};
        ok( !defined $perldoc->_explicit_pager_command, 'no explicit pager when env unset' );
    };
}

{
    my $perldoc = make_perldoc();
    subtest 'parse_pager_command' => sub {
        my ( $cmd, $args ) = $perldoc->_parse_pager_command('less -R');
        is( $cmd, 'less', 'command extracted' );
        is( $args, '-R', 'args extracted' );

        ok( !defined $perldoc->_parse_pager_command(''), 'rejects empty' );
        ok( !defined $perldoc->_parse_pager_command('less | cat'), 'rejects pipe' );
        ok( !defined $perldoc->_parse_pager_command('less > file'), 'rejects redirection' );
        ok( !defined $perldoc->_parse_pager_command('less "file"'), 'rejects quotes' );
        ok( !defined $perldoc->_parse_pager_command("less\n"), 'rejects newline' );
    };
}

{
    my $perldoc = make_perldoc();
    subtest '_pager_is_less_command' => sub {
        ok( $perldoc->_pager_is_less_command('less'), 'less allowed' );
        ok( $perldoc->_pager_is_less_command('/usr/bin/less'), 'path to less allowed' );
        ok( $perldoc->_pager_is_less_command('less.exe'), 'less.exe allowed' );
        ok( !$perldoc->_pager_is_less_command('lesspipe'), 'lesspipe rejected' );
    };
}

{
    my $perldoc = make_perldoc();
    subtest '_less_supports_r_flag' => sub {
        $perldoc->set_fake_command(qr/less/, "less 350\n");
        ok( $perldoc->_less_supports_r_flag('less'), 'less >= min supports -R' );

        $perldoc->set_fake_command(qr/less/, "less 300\n");
        ok( !$perldoc->_less_supports_r_flag('less'), 'less < min rejects -R' );

        $perldoc->set_fake_command(qr/less/, "not-less\n");
        ok( !$perldoc->_less_supports_r_flag('less'), 'missing version rejects -R' );
    };
}

{
    my $perldoc = make_perldoc( pagers => ['less'] );
    $perldoc->set_fake_command(qr/less/, "less 350\n");
    subtest '_pager_can_use_toterm' => sub {
        local $ENV{LESS};
        ok( $perldoc->_pager_can_use_toterm('less -R'), 'args include -R' );

        local $ENV{LESS};
        ok( $perldoc->_pager_can_use_toterm('less'), 'no args and LESS undefined' );

        local $ENV{LESS} = 'FRSX';
        ok( !$perldoc->_pager_can_use_toterm('less'), 'LESS set without -R rejects' );
    };
}

{
    my $perldoc = make_perldoc( pagers => ['less'] );
    $perldoc->set_fake_command(qr/less/, "less 350\n");
    subtest 'pager_configuration only mutates when safe' => sub {
        my $formatter = Pod::Perldoc::ToTerm->new;

        local $ENV{TERM} = 'xterm';
        local $ENV{PAGER};
        local $ENV{PERLDOC_PAGER};
        local $ENV{LESS};
        $formatter->pager_configuration('less', $perldoc);
        is( $ENV{LESS}, '-R', 'sets LESS when undefined and safe' );

        local $ENV{TERM} = 'xterm';
        local $ENV{LESS} = 'FRSX';
        $formatter->pager_configuration('less', $perldoc);
        is( $ENV{LESS}, 'FRSX', 'does not override existing LESS' );

        local $ENV{TERM} = 'xterm';
        local $ENV{LESS};
        $formatter->pager_configuration('less -R', $perldoc);
        ok( !defined $ENV{LESS}, 'does not set LESS when args already have -R' );

        local $ENV{TERM} = 'xterm';
        local $ENV{LESS};
        $formatter->pager_configuration('more', $perldoc);
        ok( !defined $ENV{LESS}, 'does not set LESS for non-less pager' );
    };
}

done_testing();
