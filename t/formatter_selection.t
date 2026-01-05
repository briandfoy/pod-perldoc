use strict;
use warnings;
use Test::More;

use Pod::Perldoc ();

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
}

{
    local $ENV{TERM} = 'xterm';
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
}

{
    local $ENV{TERM} = 'xterm';
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
}

{
    local $ENV{TERM} = 'dumb';
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
    is( $formatter, undef, 'falls back for dumb terminals' );
}

done_testing();
