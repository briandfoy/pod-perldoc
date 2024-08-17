#!perl
use v5.26;

=head1 NAME

fetch-pages.pl - grab particular perl documentation pages

=head1 SYNOPSIS

	% perl fetch_pages.pl
	5.40.0    perlfunc/perlfunc-5.40.0.pod    https://fastapi.metacpan.org/source/5.40.0/pod/perlfunc.pod
	5.40.0    perlop/perlop-5.40.0.pod    https://fastapi.metacpan.org/source/5.40.0/pod/perlop.pod
	5.40.0    perlvar/perlvar-5.40.0.pod    https://fastapi.metacpan.org/source/5.40.0/pod/perlvar.pod

=head1 DESCRIPTION

To ensure that Pod::Perldoc works for all the docs, we grab the historical
versions of docs to test against. Other tests can then use these pages.

This program requires Mojolicious,

	% cpan Mojolicious

=cut

use File::Path qw(make_path);

my @sections = qw(func op var);

make_path( $_ ) for( map { "perl$_" } @sections );

use Mojo::UserAgent;

my $ua = Mojo::UserAgent->new;

my $tx = $ua->get( 'https://metacpan.org/dist/perl/view/pod/perl.pod' );

my $version_pattern = qr/5\.\d*[02468]\.\d+/;

my $versions = $tx
    ->res
    ->dom
    ->at( 'select' )
    ->find( 'option' )
    ->map( attr => 'value' )
    ->grep( qr/$version_pattern/ )
    ->map( sub { m/($version_pattern)/ && $1 } )
    ;

foreach my $version ( $versions->to_array->@* ) {
    state $base = 'https://fastapi.metacpan.org/source/%s/pod/perl%s.pod';

    foreach my $page ( @sections ) {
        my $url = sprintf $base, $version, $page;
        my $file = sprintf 'perl%s/perl%s-%s.pod', $page, $page, $version;
        next if -e $file;
        say join "    ", $version, $file, $url;
        $ua->get( $url )->result->save_to( $file );
        }
    }

