package Pod::Perldoc::Highlighter;

use strict;
use warnings;

use Term::ANSIColor ':constants';

my @highlighter_classes = qw[
    Syntax::Highlight::Engine::Kate::Perl
    Syntax::Highlight::Perl::Improved
];

sub new {
    # look for various highlighter classes
    for my $class (@highlighter_classes) {
        eval "require $class";
        unless ($@) {	# found one
            return bless _init($class), __PACKAGE__;
        }
    }

    # none of them found
    return;
}

sub _init {
    my $class = shift;

    if ($class eq "Syntax::Highlight::Engine::Kate::Perl") {

        # color theme stolen from DB::Color

        my $highlighter = $class->new(
            format_table => {
                'Keyword'      => [ GREEN,    RESET ],
                'Comment'      => [ BLUE,     RESET ],
                'Decimal'      => [ YELLOW,   RESET ],
                'Float'        => [ YELLOW,   RESET ],
                'Function'     => [ CYAN,     RESET ],
                'Identifier'   => [ RED,      RESET ],
                'Normal'       => [ MAGENTA,  RESET ],
                'Operator'     => [ CYAN,     RESET ],
                'Preprocessor' => [ RED,      RESET ],
                'String'       => [ RED,      RESET ],
                'String Char'  => [ RED,      RESET ],
                'Symbol'       => [ CYAN,     RESET ],
                'DataType'     => [ YELLOW,   RESET ],
                'Variable'     => [ GREEN,    RESET ],
                'Others'       => [ BLACK,    RESET ],
                'Char'         => [ GREEN,    RESET ],
                'BaseN'        => [ BLACK,    RESET ],
                'Alert'        => [ BOLD RED, RESET ],
            }
        );

        return { highlighter => $highlighter, highlight_method => 'highlightText' };
    }
    elsif ($class eq "Syntax::Highlight::Perl::Improved") {
        my $highlighter = $class->new;

        $highlighter->unstable(1);

        $highlighter->set_format(
            'Comment_Normal'    => [ BOLD BLUE,    RESET ],
            'Comment_POD'       => [ BOLD BLUE,    RESET ],
            'Directive'         => [ MAGENTA,      RESET ],
            'Label'             => [ MAGENTA,      RESET ],
            'Quote'             => [ BOLD WHITE,   RESET ],
            'String'            => [ BOLD CYAN,    RESET ],
            'Subroutine'        => [ BOLD YELLOW,  RESET ],
            'Variable_Scalar'   => [ BOLD GREEN,   RESET ],
            'Variable_Array'    => [ BOLD GREEN,   RESET ],
            'Variable_Hash'     => [ BOLD GREEN,   RESET ],
            'Variable_Typeglob' => [ BOLD WHITE,   RESET ],
            'Whitespace'        => [ '',           '' ],
            'Character'         => [ BOLD RED,     RESET ],
            'Keyword'           => [ BOLD WHITE,   RESET ],
            'Builtin_Function'  => [ BOLD WHITE,   RESET ],
            'Builtin_Operator'  => [ BOLD WHITE,   RESET ],
            'Operator'          => [ WHITE,        RESET ],
            'Bareword'          => [ WHITE,        RESET ],
            'Package'           => [ GREEN,        RESET ],
            'Number'            => [ BOLD MAGENTA, RESET ],
            'Symbol'            => [ WHITE,        RESET ],
            'CodeTerm'          => [ BLACK,        RESET ],
            'DATA'              => [ BLACK,        RESET ],
            'Line'              => [ BOLD YELLOW,  RESET ],
            'File_Name'         => [ RED ON_WHITE, RESET ],
        );

        return { highlighter => $highlighter, highlight_method => 'format_string' };
    }
}

sub highlight {
    my ($self, $text) = @_;

    my $highlighter = $self->{highlighter};
    my $method = $self->{highlight_method};
    return $highlighter->$method($text);
}

1;
