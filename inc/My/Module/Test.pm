package My::Module::Test;

use 5.010;

use strict;
use warnings;

use Carp;

our $VERSION = '0.000_001';

use Exporter qw{ import };

our @EXPORT_OK = qw{
    parsed_value
};
our @EXPORT = @EXPORT_OK;

sub parsed_value {
    my ( $obj, $string ) = @_;
    $obj->parse( $string )
	or return $obj->value( 'gmt' );
    return $obj->err() . " '$string'";
}


1;

__END__

=head1 NAME

My::Module::Test - Provide test support for Date::ManipX::Almanac

=head1 SYNOPSIS

 use Test2::V0;

 use lib qw{ inc };
 use My::Module::Test;

 is parsed_value( $dmad, '2021 vernal equinox' ),
   '2021032009:37:06', 'Vernal equinox 2021';

=head1 DESCRIPTION

This Perl module provides testing support for
L<Date::ManipX::Almanac|Date::ManipX::Almanac>. It is private to the
C<Date-ManipX-Almanac> distribution, and subject to change without
notice. Documentation is for the benefit of the author.

All subroutines are exported by default, unless otherwise documented.

=head1 SUBROUTINES

=head2 parsed_value

 is parsed_value( $dmad, '2021 vernal equinox' ),
   '2021032009:37:06', 'Vernal equinox 2021';

This subroutine takes as its arguments a
L<Date::Manip::Almanac::Date|Date::Manip::Almanac::Date> object and a
string for it to parse. If the parse succeeds, it returns the results of
C<< $dmad->value( 'gmt' ) >>. If it fails, it returns C<< $dmad->err() >>.

=head1 SEE ALSO

L<Date::Manip::Almanac::Date|Date::Manip::Almanac::Date>

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Date-ManipX-Almanac>,
L<https://github.com/trwyant/perl-Date-ManipX-Almanac/issues/>, or in
electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
