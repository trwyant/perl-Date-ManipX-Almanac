package Date::ManipX::Almanac::Lang::spanish;

use 5.010;

use strict;
use warnings;

use parent qw{ Date::ManipX::Almanac::Lang };

use utf8;

use Carp;

our $VERSION = '0.000_01';

our $LangName = 'Spanish';

# See the Date::ManipX::Almanac::Lang POD for __body_data
sub __body_data {
    my ( $self ) = @_;
    my @season = $self->__season_to_detail();
    return [
	[ 'Astro::Coord::ECI::Sun'	=> qr/ (?: d?el \s* )? sol /smxi,
	    qr/
		(?: a \s* )? (?: el \s* )?  (?<specific> crepusculo ) \s*
		    (?: de \s* )? (?: la \s* )? (?<detail> manana | tarde ) |
		(?: al? \s* )? (?: (?: el | la ) \s* )?
		    (?<detail> mediodia | medianoche ) \s*
		    (?<specific> local ) |
		(?: el \s* )? (?<specific> equinoccio ) \s* (?:
		    (?: de \s* )? (?: la \s* )? (?<detail> primavera ) |
		    (?: del? \s* )? (?<detail> otono | marzo | sep?tiembre ) ) |
		(?: el \s* )? (?<specific> equinox ) \s* (?: de \s* )?
		    (?: <detail> invierno ) |
		(?: el \s* ) (?<specific> solsticio ) \s*
		    (?: del? | de (?: \s* la )? )? \s*
		    (?<detail> verano | invierno | junio | diciembre )
	    /smxi,
	    {	# Iterpret (?<specific> ... )
		#
		# The required data are described in the
		# Date::ManipX::Almanac::Lang POD, under __body_re().
		#
		equinoccio	=> [ quarter => {
			# NOTE diacritic stripping makes 'otoño' into
			# 'otono'.
			otono		=> $season[ 2 ],
			marzo		=> 0,
			setembre	=> 2,
			septembre	=> 2,
			primavera	=> $season[ 0 ],
		    },
		],
		equinox		=> [ quarter => {
			invierno	=> $season[ 0 ],
		    },
		],
		solsticio	=> [ quarter => {
			diciembre	=> 3,
			junio		=> 1,
			verano		=> $season[ 1 ],
			invierno	=> $season[ 3 ],
		    },
		],
		local		=> [ meridian => {
			mediodia	=> 1,
			medianoche	=> 0,
		    },
		],
		crepusculo	=> [ twilight => {
			tarde	=> 0,
			manana	=> 1,
		    },
		],
	    },
	],
	[ 'Astro::Coord::ECI::Moon'	=>
	    qr/ (?: de \s* )? (?: la \s* )? luna /smxi,
	    qr/
		(?: el \s* )? (?<specific> (?: primer | ultimo ) ) \s* cuarto
		    (?: \s* de )? (?: \s* la )? (?: \s* luna ) |
		(?: la \s* )? (?: luna \s* )? (?<specific> llena | nueva )
	    /smxi,
	    {	# Iterpret (?<specific> ... )
		#
		# The required data are described in the
		# Date::ManipX::Almanac::Lang POD, under __body_re().
		#
		nueva	=> [ quarter	=> 0 ],
		primer	=> [ quarter	=> 1 ],
		llena	=> [ quarter	=> 2 ],
		ultimo	=> [ quarter	=> 3 ],
	    }
	],
	# A map {} makes sense in English, but not in any other
	# language.
	# NOTE we don't need the Sun here, because ::VSOP87D::Sun is a
	# subclass of ::Sun.
	[ 'Astro::Coord::ECI::VSOP87D::Mercury'	=>
	    qr/ (?: d?el \s* )? mercurio /smxi ],
	[ 'Astro::Coord::ECI::VSOP87D::Venus'	=>
	    # Sic: Collins says the planet Venus is masculine, even
	    # though the mythological Venus is feminine
	    qr/ (?: d?el \s* )? venus /smxi ],
	[ 'Astro::Coord::ECI::VSOP87D::Mars' =>
	    qr/ (?: d?el \s* )? marte /smxi ],
	[ 'Astro::Coord::ECI::VSOP87D::Jupiter'	=>
	    qr/ (?: d?el \s* )? jupiter /smxi ],
	[ 'Astro::Coord::ECI::VSOP87D::Saturn'	=>
	    qr/ (?: d?el \s* )? saturno /smxi ],
	[ 'Astro::Coord::ECI::VSOP87D::Uranus'	=>
	    qr/ (?: d?el \s* )? urano /smxi ],
	[ 'Astro::Coord::ECI::VSOP87D::Neptune'	=>
	    qr/ (?: d?el \s* )? neptuno /smxi ],
    ];
}

sub __body_re_from_name {
    my ( undef, $name ) = @_;
    return "(?: del | (?: de \\s* )? la | el )? \\s* $name";
}

# See the Date::ManipX::Almanac::Lang POD for __general_event_re
#
# Return a regular expression that matches any event that must be paired
# with the name of a body. The internal name of the event must be
# captured by named capture (?<general> ... )
sub __general_event_re {
    return qr/
	(?: es \s* )? (?: el \s* )? (?<general> mas \s* alto ) |
	(?: a \s* )? (?: la \s* )? (?<general> salida ) |
	(?: a \s* )? (?: la \s* )? (?<general> puesta )
    /smxi;
}

# See the Date::ManipX::Almanac::Lang POD for __general_event_interp
#
# The interpretation of the events captured in (?<general> ... ) above.
sub __general_event_interp {
    state $rise		= [ horizon	=> 1 ];
    state $set		= [ horizon	=> 0 ];
    state $highest	= [ meridian	=> 1 ];
    return [
	{
	    culminat	=> $highest,
	    masalto	=> $highest,	# mas alto
	    salida	=> $rise,
	    puesta	=> $set,
	},
    ];
}

1;

__END__

=encoding utf-8

=head1 NAME

Date::ManipX::Almanac::Lang::spanish - Spanish support for Date::ManipX::Almanac

=head1 SYNOPSIS

The user does not directly interface with this module.

=head1 DESCRIPTION

This module provides Spanish-language support for parsing almanac
events.

B<Note> that the input normalization described in the
L<Date::ManipX::Almanac::Lang|Date::ManipX::Almanac::Lang> POD strips
diacritics. This was done for (I hope) ease of input, but it can change
the meaning of a word: sí ("so") versus si ("yes"), for example, or año
("year") versus ano ("anus"). I am hoping that because of the extremely
small vocabulary I am dealing with this will not be a problem in
practice. But some of the Spanish looks uncouth even to me, and I
apologise to any actual Spanish-speakers who have the misfortune to
examine the internals of this module.

B<Caveat:> this module has not been reviewed by someone who is actually
good at Spanish, and will not be actually distributed until that
happens. I just hacked it together to try to ensure the code would work
on a language which is more strongly inflected than English (i.e. most
of them). When in doubt (frequently) I have used The Collins Spanish
Dictionary.

=head1 ASTRONOMICAL BODIES

The following astronomical bodies are recognized:

 el sol
 del sol
 de la luna
 el mercurio
 del mercurio
 el venus
 del venus
 el marte
 del marte
 el jupiter
 del jupiter
 el saturno
 del saturno
 el urano
 del urano
 el neptuno
 del neptuno

Yes, the Collins dictionary (on which I leaned heavily) says that the
astronomical Venus is masculine, even though the mythological Venus is
feminine.

The words C<'el'>, C<'del'>, C<'de'>, and C<'la'> are optional.

=head1 ALMANAC EVENTS

This section describes the events that this class provides. Descriptions
are in terms of the superclass' documentation, and so will look a bit
redundant in English.

Incidental words like C<'the'> and C<'of'> are supported where the
author found them natural and bothered to allow for them, but do (or at
least should) not affect the parse.

For the purpose of discussion, events are divided into two classes.
L<General Events|/General Events> are those that apply to any
astronomical body, and which therefore require the specification of the
body they apply to. L<Specific Events|/Specific Events> only apply to
one body, and therefore do not require the naming of a specific body.

=head1 General Events

The following general events should be recognized by this class:

=over

=item Culminates

This is defined as the moment when the body appears highest in the sky.
This module recognizes

 es el mas alto

which I put together from my lame and rusty Spanish. I have no idea
whether the translation of "culminate" has an astronomical meaning in
Spanish.

The words C<'es'> and C<'el'> are optional.

=item Rise

This is defined as the moment when the upper limb of the body appears
above the horizon, after correcting for atmospheric refraction. This
module recognizes

 a la salida

The words C<a> and C<'la'> are optional.

=item Set

This is defined as the moment when the upper limb of the body disappears
below the horizon, after correcting for atmospheric refraction. This
module recognizes

 a la puesta

The words C<a> and C<'la'> are optional.

=back

=head1 Specific Events

The following specific events should be recognized by any subclass:

=over

=item Phases of the Moon

 la luna nueva
 el primer cuarto de la luna
 la luna llena
 el ultimo cuarto de la luna

This implies the Moon. It computes the first occurrence of the specified
phase on or after the specified date.

The words C<'la'>, C<'luna'>, C<'el'>, and C<'de'> are optional.

=item Solar quarters

 el equinoccio de la primavera
 el equinoccio del otono
 el equinoccio del marzo
 el equinoccio del seteiembre
 el equinoccio del septeiembre
 el equinox de invierno
 el solsticio del verano
 el solsticio del invierno
 el solsticio del junio
 el solsticio del diciembre

This implies the Sun. It computes the first occurrence of the specified
quarter after the specified date. B<Note> that the time specified by the
seasonal names differs between Northern and Southern Hemispheres.

C<'equinox de invierno'> was Collins' translation of 'vernal equinox'.

The words C<'el'>, C<'la'>, C<'de'>, and C<'del'> are optional.

=item twilight

 a el crepusculo de la manana
 a el crepusculo de la tarde

This implies the Sun, and specifies the time the center of the Sun
passes above (C<'manana'>) or below (C<'tarde'>) the twilight setting of
the C<location> object. This defaults to civil twilight (in the U.S. at
least), or 6 degrees below the horizon.

The words C<'a'>, C<'el'>, C<'la'>, and C<'de'> are optional.

=item noon

 al mediodia local
 el mediodia local
 la medianoche local
 a la medianoche local

This implies the Sun. The C<'mediodia local'> specification is
equivalent to C<'sun culminates'>.

The words C<'a'>, C<'al'>, C<'el'> and C<'la'> are optional.

I have simply assumed that the literal translation of the English
phrases mean the same thing in Spanish, though "mediodia local" might
mean, for instance, "noon in this time zone."

=back

=head1 SEE ALSO

L<Date::ManipX::Almanac::Lang|Date::ManipX::Almanac::Lang>

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Date-ManipX-Astro-Lang-english>,
L<https://github.com/trwyant/perl-Date-ManipX-Astro-Lang-english/issues/>, or in
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
