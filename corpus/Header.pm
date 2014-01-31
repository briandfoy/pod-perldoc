package Blosxom::Header;
use 5.008_009;
use strict;
use warnings;
use overload '%{}' => 'as_hashref', 'fallback' => 1;
use Exporter 'import';
use Carp qw/croak carp/;
use List::Util qw/first/;
use Scalar::Util qw/refaddr/;

BEGIN {
    *clear = \&CLEAR;    *exists = \&EXISTS;
    *new   = \&instance; *type   = \&content_type;
}

our $VERSION = '0.06000';

our @EXPORT_OK = qw(
    header_get    header_set  header_exists
    header_delete header_iter
);

sub header_get    { __PACKAGE__->instance->get( @_ )    }
sub header_set    { __PACKAGE__->instance->set( @_ )    }
sub header_exists { __PACKAGE__->instance->exists( @_ ) }
sub header_delete { __PACKAGE__->instance->delete( @_ ) }
sub header_iter   { __PACKAGE__->instance->each( @_ )   }

# instance variables
my ( %header_of, %adaptee_of );

my $instance;

sub instance {
    my $class = shift;

    return $class    if ref $class;
    return $instance if defined $instance;

    if ( $class->is_initialized ) {
        my $self = tie my %header => $class => $blosxom::header;
        $header_of{ refaddr $self } = \%header;
        return $instance = $self;
    }

    croak( q{$blosxom::header hasn't been initialized yet} );
}

sub has_instance { $instance }

sub is_initialized { ref $blosxom::header eq 'HASH' }

sub as_hashref { $header_of{ refaddr shift } }

sub get {
    my ( $self, @fields ) = @_;

    if ( @fields ) {
        if ( @fields > 1 ) {
            my @values = map { $self->FETCH( $_ ) } @fields;
            return wantarray ? @values : $values[0];
        }
        else {
            return $self->FETCH( $fields[0] );
        }
    }

    return;
}

sub set {
    my ( $self, @headers ) = @_;
    
    if ( @headers ) {
        if ( @headers % 2 == 0 ) {
            while ( my ($field, $value) = splice @headers, 0, 2 ) {
                $self->STORE( $field => $value );
            }
        }
        else {
            carp( 'Odd number of elements passed to set()' );
        }
    }

    return;
}

sub delete {
    my ( $self, @fields ) = @_;

    if ( @fields ) {
        if ( defined wantarray ) {
            my @deleted = map { $self->DELETE( $_ ) } @fields;
            return wantarray ? @deleted : $deleted[-1];
        }
        else {
            $self->DELETE( $_ ) for @fields;
        }
    }

    return;
}

sub each {
    my ( $self, $callback ) = @_;

    if ( ref $callback eq 'CODE' ) {
        for my $field ( $self->field_names ) {
            $callback->( $field, $self->FETCH( $field ) );
        }
    }
    else {
        croak( 'Must provide a code reference to each()' );
    }

    return;
}

sub flatten {
    my $self = shift;
    map { $_, $self->FETCH( $_ ) } $self->field_names;
}

sub is_empty { !shift->SCALAR }

sub charset {
    my $self = shift;

    my $charset;
    for ( $self->FETCH( 'Content-Type' ) || q{} ) {
        if    ( /charset\s*=\s*\"([^\"]*)\"/ ) { $charset = $1 } # quoted
        elsif ( /charset\s*=\s*([^;\s]*)/    ) { $charset = $1 } # unquoted
    }

    $charset && uc $charset;
}

sub content_type {
    my $self = shift;

    if ( @_ ) {
        $self->STORE( Content_Type => shift );
    }
    elsif ( my $content_type = $self->FETCH( 'Content-Type' ) ) {
        my ( $media_type, $rest ) = split /;\s*/, $content_type, 2;
        $media_type =~ s/\s+//g;
        return wantarray ? ( lc $media_type, $rest ) : lc $media_type;
    }
    else {
        return q{};
    }

    return;
}

# constructor
sub TIEHASH {
    my $self = bless \do { my $anon_scalar }, shift;
    $adaptee_of{ refaddr $self } = shift;
    $self;
}

sub FETCH {
    my $self   = shift;
    my $norm   = $self->_normalize( shift );
    my $header = $adaptee_of{ refaddr $self };

    if ( $norm eq '-content_type' ) {
        my $type    = $header->{-type};
        my $charset = $header->{-charset};

        if ( defined $type and $type eq q{} ) {
            undef $charset;
            undef $type;
        }
        else {
            $type ||= 'text/html';

            if ( $type =~ /\bcharset\b/ ) {
                undef $charset;
            }
            elsif ( !defined $charset ) {
                $charset = 'ISO-8859-1';
            }
        }

        return $charset ? "$type; charset=$charset" : $type;
    }
    elsif ( $norm eq '-content_disposition' ) {
        if ( my $attachment = $header->{-attachment} ) {
            return qq{attachment; filename="$attachment"};
        }
    }
    elsif ( $norm eq '-date' ) {
        if ( $self->_date_header_is_fixed ) {
            require HTTP::Date;
            return HTTP::Date::time2str( time );
        }
    }
    elsif ( $norm eq '-p3p' ) {
        if ( my $p3p = $header->{-p3p} ) {
            my $tags = ref $p3p eq 'ARRAY' ? join ' ', @{ $p3p } : $p3p;
            return qq{policyref="/w3c/p3p.xml", CP="$tags"};
        }
        else {
            return;
        }
    }

    $header->{ $norm };
}

sub STORE {
    my $self   = shift;
    my $norm   = $self->_normalize( shift );
    my $value  = shift;
    my $header = $adaptee_of{ refaddr $self };

    if ( $norm eq '-date' and $self->_date_header_is_fixed ) {
        return carp( 'The Date header is fixed' );
    }
    elsif ( $norm eq '-content_type' ) {
        if ( $value =~ s/\b(charset)\b/\L$1/i ) {
            delete $header->{-charset};
        } else {
            $header->{-charset} = q{};
        }
        $norm = '-type';
    }
    elsif ( $norm eq '-content_disposition' ) {
        delete $header->{-attachment};
    }
    elsif ( $norm eq '-expires' or $norm eq '-cookie' ) {
        delete $header->{-date};
    }
    elsif ( $norm eq '-p3p' ) {
        return;
    }

    $header->{ $norm } = $value;

    return;
}

sub DELETE {
    my $self    = shift;
    my $field   = shift;
    my $norm    = $self->_normalize( $field );
    my $deleted = defined wantarray && $self->FETCH( $field );
    my $header  = $adaptee_of{ refaddr $self };

    if ( $norm eq '-date' and $self->_date_header_is_fixed ) {
        return carp( 'The Date header is fixed' );
    }
    elsif ( $norm eq '-content_type' ) {
        delete $header->{-charset};
        $header->{-type} = q{};
    }
    elsif ( $norm eq '-content_disposition' ) {
        delete $header->{-attachment};
    }

    delete $header->{ $norm };

    $deleted;
}

sub CLEAR {
    my $self = shift;
    my $id = refaddr $self;
    %{ $adaptee_of{$id} } = ( -type => q{} );
}

sub EXISTS {
    my $self   = shift;
    my $norm   = $self->_normalize( shift );
    my $header = $adaptee_of{ refaddr $self };

    if ( $norm eq '-content_type' ) {
        return !defined $header->{-type} || $header->{-type} ne q{};
    }
    elsif ( $norm eq '-content_disposition' ) {
        return 1 if $header->{-attachment};
    }
    elsif ( $norm eq '-date' ) {
        my $h = $header;
        return 1 if $h->{-nph} or $h->{-expires} or $h->{-cookie};
    }

    $header->{ $norm };
}

sub SCALAR {
    my $self = shift;
    my $header = $adaptee_of{ refaddr $self };
    $self->EXISTS( 'Content-Type' ) || first { $_ } values %{ $header };
}

sub UNTIE {
    my $self = shift;
    delete $header_of{ refaddr $self };
    return;
}

sub DESTROY {
    my $self = shift;
    my $id = refaddr $self;
    delete $header_of{$id};
    delete $adaptee_of{$id};
    return;
}

sub field_names {
    my $self   = shift;
    my $header = $adaptee_of{ refaddr $self };
    my %header = %{ $header };

    my @fields;

    push @fields, 'Status'        if delete $header{-status};
    push @fields, 'Window-Target' if delete $header{-target};
    push @fields, 'P3P'           if delete $header{-p3p};

    push @fields, 'Set-Cookie' if my $cookie  = delete $header{-cookie};
    push @fields, 'Expires'    if my $expires = delete $header{-expires};
    push @fields, 'Date' if delete $header{-nph} or $cookie or $expires;

    push @fields, 'Content-Disposition' if delete $header{-attachment};

    # not ordered
    delete @header{qw/-charset -type/};
    while ( my ($norm, $value) = CORE::each %header ) {
        push @fields, $self->_denormalize( $norm ) if $value;
    }

    push @fields, 'Content-Type' if $self->EXISTS( 'Content-Type' );

    @fields;
}

sub attachment {
    my $header = $adaptee_of{ refaddr shift };
    return $header->{-attachment} = shift if @_;
    $header->{-attachment};
}

sub date {
    my $self   = shift;
    my $time   = shift;
    my $header = $adaptee_of{ refaddr $self };

    require HTTP::Date;

    if ( defined $time ) {
        $self->STORE( Date => HTTP::Date::time2str( $time ) );
    }
    elsif ( $self->_date_header_is_fixed ) {
        return time;
    }
    elsif ( my $date = $header->{-date} ) {
        return HTTP::Date::str2time( $date );
    }

    return;
}

my %expires;
sub expires {
    my $self   = shift;
    my $header = $adaptee_of{ refaddr $self };

    if ( @_ ) {
        $header->{-expires} = shift;
    }
    elsif ( my $expires = $header->{-expires} ) {
        if ( exists $expires{ $expires } ) {
            return $expires{ $expires };
        }
        else { # TODO: expensive process
            require CGI::Util;
            require HTTP::Date;

            my $date = CGI::Util::expires( $expires );
            my $time = HTTP::Date::str2time( $date );

            return $expires{ $expires } = $time;
        }
    }

    return;
}

sub last_modified {
    my $self   = shift;
    my $time   = shift;
    my $header = $adaptee_of{ refaddr $self };

    require HTTP::Date;

    if ( defined $time ) {
        $header->{-last_modified} = HTTP::Date::time2str( $time );
    }
    elsif ( my $date = $header->{-last_modified} ) {
        return HTTP::Date::str2time( $date );
    }

    return;
}

sub nph {
    my $self   = shift;
    my $header = $adaptee_of{ refaddr $self };
    
    if ( @_ ) {
        my $nph = shift;
        delete $header->{-date} if $nph;
        $header->{-nph} = $nph;
    }
    else {
        return $header->{-nph};
    }

    return;
}

sub p3p_tags {
    my $self   = shift;
    my $header = $adaptee_of{ refaddr $self };

    if ( @_ ) {
        my @tags = @_ > 1 ? @_ : split / /, shift;
        $header->{-p3p} = @tags > 1 ? \@tags : $tags[0];
    }
    elsif ( my $tags = $header->{-p3p} ) {
        my @tags = ref $tags eq 'ARRAY' ? @{ $tags } : split / /, $tags;
        return wantarray ? @tags : $tags[0];
    }

    return;
}

sub push_p3p_tags {
    my ( $self, @tags ) = @_;

    if ( @tags ) {
        my $header = $adaptee_of{ refaddr $self };

        if ( my $tags = $header->{-p3p} ) {
            return push @{ $tags }, @tags if ref $tags eq 'ARRAY';
            unshift @tags, $tags;
        }

        $header->{-p3p} = @tags > 1 ? \@tags : $tags[0];

        return scalar @tags;
    }

    return;
}

sub set_cookie {
    my $self   = shift;
    my $name   = shift;
    my $value  = shift;
    my $header = $adaptee_of{ refaddr $self };

    require CGI::Cookie;

    my $new_cookie = CGI::Cookie->new(do {
        my %args = ref $value eq 'HASH' ? %{ $value } : ( value => $value );
        $args{name} = $name;
        \%args;
    });

    my @cookies;
    if ( my $cookies = $header->{-cookie} ) {
        @cookies = ref $cookies eq 'ARRAY' ? @{ $cookies } : $cookies;
        for my $cookie ( @cookies ) {
            if ( ref $cookie eq 'CGI::Cookie' and $cookie->name eq $name ) {
                $cookie = $new_cookie;
                undef $new_cookie;
                last;
            }
        }
    }

    push @cookies, $new_cookie if $new_cookie;

    $header->{-cookie} = @cookies > 1 ? \@cookies : $cookies[0];

    return;
}

sub get_cookie {
    my $self   = shift;
    my $name   = shift;
    my $header = $adaptee_of{ refaddr $self };

    if ( my $cookies = $header->{-cookie} ) {
        my @values = grep {
            ref $_ eq 'CGI::Cookie' and $_->name eq $name
        } (
            ref $cookies eq 'ARRAY' ? @{ $cookies } : $cookies,
        );
        return wantarray ? @values : $values[0];
    }

    return;
}

sub status {
    my $self   = shift;
    my $header = $adaptee_of{ refaddr $self };

    require HTTP::Status;

    if ( @_ ) {
        my $code = shift;
        my $message = HTTP::Status::status_message( $code );
        return $header->{-status} = "$code $message" if $message;
        carp( qq{Unknown status code "$code" passed to status()} );
    }
    elsif ( my $status = $header->{-status} ) {
        return substr( $status, 0, 3 );
    }

    return;
}

sub target {
    my $header = $adaptee_of{ refaddr shift };
    return $header->{-target} = shift if @_;
    $header->{-target};
}

my %norm_of = (
    -attachment => q{},        -charset       => q{},
    -cookie     => q{},        -nph           => q{},
    -set_cookie => q{-cookie}, -target        => q{},
    -type       => q{},        -window_target => q{-target},
);

sub _normalize {
    my $self  = shift;
    my $field = lc shift;

    # transliterate dashes into underscores
    $field =~ tr{-}{_};

    # add an initial dash
    $field = "-$field";

    return $norm_of{ $field } if exists $norm_of{ $field };

    $field;
}

my %field_name_of = (
    -attachment => 'Content-Disposition', -cookie => 'Set-Cookie',
    -p3p        => 'P3P',                 -target => 'Window-Target',
    -type       => 'Content-Type',
);

sub _denormalize {
    my ( $self, $norm ) = @_;

    unless ( exists $field_name_of{ $norm } ) {
        ( my $field = $norm ) =~ s/^-//;
        $field =~ tr/_/-/;
        return $field_name_of{ $norm } = ucfirst $field;
    }

    $field_name_of{ $norm };
}

sub _date_header_is_fixed {
    my $header = $adaptee_of{ refaddr shift };
    $header->{-expires} || $header->{-cookie} || $header->{-nph};
}

sub _dump {
    my $self = shift;

    require Data::Dumper;

    local $Data::Dumper::Terse  = 1;
    local $Data::Dumper::Indent = 1;

    Data::Dumper::Dumper({
        adaptee => $adaptee_of{ refaddr $self },
        header  => { $self->flatten },
    });
}

1;

__END__

=head1 NAME

Blosxom::Header - Object representing CGI response headers

=head1 SYNOPSIS

  use Blosxom::Header;

  my $header = Blosxom::Header->instance;

  $header->set( Content_Length => 12345 );
  my $value   = $header->get( 'Status' );
  my $deleted = $header->delete( 'Content-Disposition' );
  my $bool    = $header->exists( 'ETag' );

  # as a hash reference
  $header->{Content_Length} = 12345;
  my $value   = $header->{Status};
  my $deleted = delete $header->{Content_Disposition};
  my $bool    = exists $header->{ETag};

  # procedural interface
  use Blosxom::Header qw(
      header_get    header_set
      header_exists header_delete
  );

  header_set( Content_Length => 12345 );
  my $value   = header_get( 'Status' );
  my $deleted = header_delete( 'Content-Disposition' );
  my $bool    = header_exists( 'ETag' );

=head1 DESCRIPTION

This module provides Blosxom plugin developers
with an interface to handle L<CGI> response headers.
Blosxom starts speaking HTTP at last.

=head2 BACKGROUND

Blosxom, an weblog application, globalizes C<$header> which is a hash reference.
This application passes C<$header> to C<CGI::header()> to generate
CGI response headers.

Blosxom plugins may modify C<$header> directly because the variable is
global.
The problem is that there is no agreement with how to normalize C<keys>
of C<$header>.
If we normalized them, plugins would be compatible with each other.

In addition, C<CGI::header()> doesn't behave intuitively.
It's difficult for us to predict what the subroutine will return
unless we execute it.
Although CGI's pod tells us how it will work,
it's painful for lazy people to reread the document
whenever they manipulate CGI response headers.
It lowers their productivity.
While it's easy to replace CGI.pm with other modules,
this module extends Blosxom without rewriting C<blosxom.cgi>.

=head2 CLASS METHODS

=over 4

=item $header = Blosxom::Header->instance

Returns a current Blosxom::Header object instance or create a new one.
C<new()> is an alias.

=item $header = Blosxom::Header->has_instance

Returns a reference to any existing instance or C<undef> if none is defined.

=item $bool = Blosxom::Header->is_initialized

Returns a Boolean value telling whether C<$blosxom::header> is initialized or
not. Blosxom initializes the variable just before C<blosxom::generate()> is
called. If C<$bool> was false, C<instance()> would throw an exception.

Internally, this method is a shortcut for

  $bool = ref $blosxom::header eq 'HASH';

=back

=head2 INSTANCE METHODS

=over 4

=item $value = $header->get( $field )

=item @values = $header->get( @fields )

Returns the value of one or more header fields.
Accepts a list of field names case-insensitive.
You can use underscores as a replacement for dashes in header names.

  # field names are case-insensitive
  $header->get( 'Content-Length' );
  $header->get( 'content_length' );

=item $header->set( $field => $value )

=item $header->set( $f1 => $v1, $f2 => $v2, ... )

Sets the value of one or more header fields.
Accepts a list of named arguments.

The $value argument must be a plain string, except for when the Set-Cookie
header is specified.
In an exceptional case, $value may be a reference to an array.

  use CGI::Cookie;

  my $cookie1 = CGI::Cookie->new( -name => 'foo' );
  my $cookie2 = CGI::Cookie->new( -name => 'bar' );

  $header->set( Set_Cookie => [ $cookie1, $cookie2 ] );

=item $bool = $header->exists( $field )

Returns a Boolean value telling whether the specified HTTP header exists.

  if ( $header->exists( 'ETag' ) ) {
      ....
  }

=item @deleted = $header->delete( @fields )

Deletes the specified fields from HTTP headers.
Returns values of deleted fields.

  $header->delete( qw/Content-Type Content-Length Content-Disposition/ );

=item $header->clear

This will remove all header fields.

  $header->clear;

Internally, this method is a shortcut for

  %{ $blosxom::header } = ( -type => q{} );

=item @fields = $header->field_names

Returns the list of distinct names for the fields present in the header.
The field names have case as returned by C<CGI::header()>.

  my @fields = $header->field_names;
  # => ( 'Set-Cookie', 'Content-length', 'Content-Type' )

In scalar context return the number of distinct field names.

=item $header->each( \&callback )

Apply a subroutine to each header field in turn.
The callback routine is called with two parameters;
the name of the field and a value.
Any return values of the callback routine are ignored.

  $header->each(sub {
      my ( $field, $value ) = @_;
      ...
  });

=item $bool = $header->is_empty

Returns a Boolean value telling whether C<< $header->field_names >>
returns a null array or not.

  $header->clear;

  if ( $header->is_empty ) { # true
      ...
  }

=item @headers = $header->flatten

Returns pairs of fields and values.

  my @headers = $header->flatten;
  # => ( 'Status', '304 Not Modified', 'Content-Type', 'text/plain' )

=item $hashref = $header->as_hashref

Returns a reference to hash which represents header fields.
You can C<set()>, C<get()> and C<delete()> header fields using the hash
syntax.

  $header->as_hashref->{Foo} = 'bar';
  my $value = $header->as_hashref->{Foo};
  my $deleted = delete $header->as_hashref->{Foo};

Since the hash dereference operator of C<$header> is L<overload>ed
with C<as_hashref()>,
you can omit calling C<as_hashref()> method from the above operations:

  $header->{Foo} = 'bar';
  my $value = $header->{Foo};
  my $deleted = delete $header->{Foo};

NOTE: You can't iterate over C<$header> using C<CORE::each()>, C<CORE::keys()>
or C<CORE::values()>. Use C<< $header->field_names >> or C<< $header->each >>
instead.

  # wrong
  keys %{ $header };
  values %{ $header };
  each %{ $header };

=back

=head3 HANDLING COOKIES

=over 4

=item $header->set_cookie( $name => $value )

=item $header->set_cookie( $name => { value => $value, ... } )

Overwrites existent cookie.

  $header->set_cookie( ID => 123456 );

  $header->set_cookie(
      ID => {
         value   => '123456',
         path    => '/',
         domain  => '.example.com',
         expires => '+3M',
      }
  );

=item $cookie = $header->get_cookie( $name )

Returns a L<CGI::Cookie> object whose C<name()> is stringwise equal to C<$name>.

  my $id = $header->get_cookie( 'ID' ); # CGI::Cookie object
  my $value = $id->value; # 123456

=back

=head3 DATE HEADERS

These methods always convert their value to system time
(seconds since Jan 1, 1970).

=over 4

=item $mtime = $header->date

=item $header->date( $mtime )

This header represents the date and time at which the message
was originated. This method expects machine time when the header
value is set.

  $header->date( time ); # set current date

=item $mtime = $header->expires

=item $header->expires( $mtime )

The Expires header gives the date and time after which the entity should be
considered stale.
You can specify an absolute or relative expiration interval.
The following forms are all valid for this field:

  $header->expires( '+30s' ); # 30 seconds from now
  $header->expires( '+10m' ); # ten minutes from now
  $header->expires( '+1h'  ); # one hour from now
  $header->expires( '-1d'  ); # yesterday
  $header->expires( 'now'  ); # immediately
  $header->expires( '+3M'  ); # in three months
  $header->expires( '+10y' ); # in ten years time

  # at the indicated time & date
  $header->expires( 'Thu, 25 Apr 1999 00:40:33 GMT' );

  # another representation of 'now'
  $header->expires( time );

=item $mtime = $header->last_modified

=item $header->last_modified( $mtime )

This header indicates the date and time at which the resource was
last modified. This method expects machine time when the header value is set.

  # check if document is more than 1 hour old
  if ( my $last_modified = $header->last_modified ) {
      if ( $last_modified < time - 60 * 60 ) {
          ...
      }
  }

=back

=head3 CONVENIENCE METHODS

The following methods were named after parameters recognized by
C<CGI::header()>.
These can both be used to read and to set the value of a header.
The value is set if you pass an argument to the method.
If the given header wasn't defined then C<undef> would be returned.

=over 4

=item $header->attachment

Can be used to turn the page into an attachment.
Represents suggested name for the saved file.

  $header->attachment( 'genome.jpg' );
  my $attachment = $header->attachment; # genome.jpg

  my $disposition = $header->get( 'Content-Disposition' );
  # => 'attachment; filename="genome.jpg"'

=item $charset = $header->charset

Returns the upper-cased character set specified in the Content-Type header.

  $header->content_type( 'text/plain; charset=utf-8' );
  my $charset = $header->charset; # UTF-8

This method doesn't receive any arguments.

  # wrong
  $header->charset( 'euc-jp' );

=item $media_type = $header->content_type

=item ( $media_type, $rest ) = $header->content_type

=item $header->content_type( 'text/html; charset=ISO-8859-1' )

Represents the Content-Type header which indicates the media type of
the message content. C<type()> is an alias.

  $header->content_type( 'text/plain; charset=utf-8' );

The value returned will be converted to lower case, and potential parameters
will be chopped off and returned as a separate value if in an array context.

  my $type = $header->content_type; # 'text/plain'
  my @type = $header->content_type; # ( 'text/plain', 'charset=utf-8' )

If there is no such header field, then the empty string is returned.
This makes it safe to do the following:

  if ( $header->content_type eq 'text/html' ) {
      ...
  }

=item $header->nph

If set to a true value,
will issue the correct headers to work with
a NPH (no-parse-header) script:

  $header->nph( 1 );

=item @tags = $header->p3p_tags

=item $header->p3p_tags( @tags )

Represents the P3P tags.
The parameter can be an array or a space-delimited string.

  $header->p3p_tags( qw/CAO DSP LAW CURa/ );
  $header->p3p_tags( 'CAO DSP LAW CURa' );

  my @tags = $header->p3p_tags; # ( 'CAO', 'DSP', 'LAW', 'CURa' )

In this case, the outgoing header will be formatted as:

  P3P: policyref="/w3c/p3p.xml", CP="CAO DSP LAW CURa"

=item $header->push_p3p_tags( @tags )

Adds P3P tags to the P3P header.
Accepts a list of P3P tags.

  # get P3P tags
  my @tags = $header->p3p_tags; # ( 'CAO', 'DSP', 'LAW' )

  # add P3P tags
  $header->push_p3p_tags( 'CURa' );

  @tags = $header->p3p_tags; # ( 'CAO', 'DSP', 'LAW', 'CURa' )

=item $code = $header->status

=item $header->status( $code )

Represents HTTP status code.

  $header->status( 304 );
  my $code = $header->status; # 304

cf.

  $header->set( Status => '304 Not Modified' );
  my $status = $header->get( 'Status' ); # 304 Not Modified

=item $header->target

Represents the Window-Target header.

  $header->target( 'ResultsWindow' );
  my $target = $header->target; # ResultsWindow

cf.

  $header->set( Window_Target => 'ResultsWindow' );
  $target = $header->get( 'Window-Target' ); # ResultsWindow

=back

=head2 FUNCTIONS

The following functions are exported on demand.

=over 4

=item @values = header_get( @fields )

A shortcut for

  @values = Blosxom::Header->instance->get( @fields );

=item header_set( $field => $value )

=item header_set( $f1 => $v2, $f2 => $v2, ... )

A shorcut for

  Blosxom::Header->instance->set( $field => $value );
  Blosxom::Header->instance->set( $f1 => $v1, $f2 => $v2, ... );

=item $bool = header_exists( $field )

A shortcut for

  $bool = Blosxom::Header->instance->exists( $field );

=item @deleted = header_delete( @fields )

A shorcut for

  @deleted = Blosxom::Header->instance->delete( @fields );

=item header_iter( \&callback )

A shortcut for 

    Blosxom::Header->instance->each( \&callback );

E.g.:

  header_iter sub {
      my ($field, $value) = @_;
      print "$field: $value";
  };

=back

=head1 LIMITATIONS

Each header field is restricted to appear only once,
except for the Set-Cookie header.
That's why C<$header> can't C<push()> header fields unlike L<HTTP::Headers>
objects. This feature originates from how C<CGI::header()> behaves.

=head2 THE P3P HEADER

Since C<CGI::header()> restricts where the policy-reference file is located,
you can't modify the location (C</w3c/p3p.xml>).
The subroutine outputs the P3P header in the following format:

  P3P: policyref="/w3c/p3p.xml", CP="%s"

therefore the following code doesn't work as you expect:

  # wrong
  $header->set( P3P => q{policyref="/path/to/p3p.xml"} );

You're allowed to set or add P3P tags by using C<< $header->p3p_tags >>
or C<< $header->push_p3p_tags >>.

=head2 THE DATE HEADER

C<CGI::header()> fixes the Date header when any of
C<< $header->get( 'Set-Cookie' ) >>,
C<< $header->expires >> or C<< $header->nph >> returns true. 
When the Date header is fixed, you can't modify the value:

  $header->set_cookie( ID => 123456 );
  # => CGI::header() fixes the Date header

  my $bool = $header->date == CORE::time(); # true

  # wrong
  $header->date( $time );
  $header->set( Date => $date );

=head1 DIAGNOSTICS

=over 4

=item $blosxom::header hasn't been initialized yet

You attempted to create a Blosxom::Header object
before the variable was initialized.
See C<< Blosxom::Header->is_initialized() >>.

=item Useless use of %s with no values

You used the C<push_cookie()> or C<push_p3p()> method with no argument
apart from the array,
like C<< $header->push_cookie() >> or C<< $header->push_p3p() >>.

=item Unknown status code "%d%d%d" passed to status()

The given status code is unknown to L<HTTP::Status>.

=back

=head1 DEPENDENCIES

L<Blosxom 2.0.0|http://blosxom.sourceforge.net/> or higher.

=head1 SEE ALSO

L<HTTP::Headers>,
L<Plack::Util>,
L<Class::Singleton>

=over 4

=item D. Robinson and K.Coar, "The Common Gateway Interface (CGI) Version 1.1",
L<RFC 3875|http://tools.ietf.org/html/rfc3875#section-6>, October 2004

=back

=head1 ACKNOWLEDGEMENT

Blosxom was originally written by Rael Dornfest.
L<The Blosxom Development Team|http://sourceforge.net/projects/blosxom/>
succeeded to the maintenance.

=head1 BUGS

There are no known bugs in this module.
Please report problems to ANAZAWA (anazawa@cpan.org).
Patches are welcome.

=head1 AUTHOR

Ryo Anazawa (anazawa@cpan.org)

=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut

