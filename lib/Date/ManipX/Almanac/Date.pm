package Date::ManipX::Almanac::Date;

use 5.010;

use strict;
use warnings;

use parent qw{ Date::Manip::Date };

use Astro::Coord::ECI 0.119;	# For clone() to work.
use Astro::Coord::ECI::Utils 0.119 qw{ TWOPI };
use Carp;
use Module::Load ();
use Scalar::Util ();

our $VERSION = '0.000_002';

use constant REF_ARRAY	=> ref [];
use constant REF_HASH	=> ref {};
use constant METERS_PER_KILOMETER	=> 1000;

sub new {
    my ( $class, @args ) = @_;
    my @config;
    REF_ARRAY eq ref $args[-1]
	and @config = @{ pop @args };

    my ( $self, $from );
    if ( ref $class ) {
	# NOTE that Date::Manip::Date's new() method seems to be
	# well-behaved (for my purposes) when the invocant is another
	# object.
	$self = $class->SUPER::new( @args );
	$from = $class;
    } else {
	# NOTE logical encapsulation violation: Date::Manip::Date's
	# new() method contains logic based on the class of the
	# invocant, and this logic takes an undesirable branch if I just
	# do $class->new(). So though this implementation does not reach
	# into Date::Manip::Date, it is chosen based on knowledge of
	# what goes on inside the black box.

	# We rely on _init_almanac() to Do The Right Thing with $from.
	$from = $args[0];
	$self = Date::Manip::Date->new( @args );
	bless $self, $class;
    }

    $self->_init_almanac( $from );
    @config
	and $self->config( @config );
    $self->get_config( 'sky' )
	or $self->_config_almanac_default_sky();
    return $self;
}

sub config {
    my ( $self, @arg ) = @_;

    my $attr = $self->_get_my_attr();
    delete $attr->{err};

    while ( @arg ) {
	my ( $name, $val ) = splice @arg, 0, 2;

	state $config = {
	    configfile	=> \&_config_almanac_configfile,
	    defaults	=> \&_config_almanac_default,
	    language	=> \&_config_almanac_var_language,
	    location	=> \&_config_almanac_var_location,
	    sky		=> \&_config_almanac_var_sky,
	    twilight	=> \&_config_almanac_var_twilight,
	};

	if ( my $code = $config->{ lc $name } ) {
	    $code->( $self, $name, $val );
	} else {
	    $self->SUPER::config( $name, $val );
	}
    }

    return;
}

sub err {
    my ( $self ) = @_;
    my $attr = $self->_get_my_attr();
    return $attr->{err} // $self->SUPER::err();
}

sub get_config {
    my ( $self, @arg ) = @_;
    my $attr = $self->_get_my_attr();
    delete $attr->{err};
    my @rslt;

    foreach my $name ( @arg ) {
	state $mine = { map { $_ => 1 } qw{ location sky twilight } };
	push @rslt, $mine->{$name} ?
	    $attr->{config}{$name} :
	    $self->SUPER::get_config( $name );
    }

    return 1 == @rslt ? $rslt[0] : @rslt;
}

sub parse {
    my ( $self, $string ) = @_;
    my ( $idate, @event ) = $self->__parse_pre( $string );
    return $self->SUPER::parse( $idate ) || $self->__parse_post( @event );
}

sub parse_time {
    my ( $self, $string ) = @_;
    my ( $idate, @event ) = $self->__parse_pre( $string );
    return $self->SUPER::parse_time( $idate ) || $self->__parse_post( @event );
}

sub _config_almanac_configfile {
    # my ( $self, $name, $val ) = @_;
    my ( $self, undef, $val ) = @_;
    my $rslt;
    my @almanac;
    {
	my $tz = $self->tz();
	my $base = $tz->base();
	# NOTE encapsulation violation
	local $base->{data}{sections}{almanac} = undef;
	$tz->config( configfile => $val );
	@almanac = @{ $base->{data}{sections}{almanac} || [] };
    }

    my %config = (
	sky	=> \my @sky,
    );

    while ( @almanac ) {
	my ( $name, $val ) = splice @almanac, 0, 2;
	if ( REF_ARRAY eq ref $config{$name} ) {
	    push @{ $config{$name} }, $val;
	} else {
	    $config{$name} = $val;
	}
    }
    delete $config{sky};

    $self->_config_almanac_var_twilight(
	twilight	=> delete $config{twilight},
    );

    keys %config
	and $rslt = $self->_config_almanac_var_location(
	    location => \%config,
	)
	and return $rslt;

    @sky
	and $rslt = $self->_config_almanac_var_sky( sky => \@sky )
	and return $rslt;

    return $rslt;
}

sub _config_almanac_default {
    my ( $self, $name, $val ) = @_;
    %{ $self->_get_my_attr() } = ();
    my $rslt = $self->SUPER::config( $name, $val ) ||
	$self->_config_almanac_default_sky();
    return $rslt;
}

sub _config_almanac_default_sky {
    my ( $self ) = @_;
    return $self->_config_almanac_var_sky( sky => [ qw{
	    Astro::Coord::ECI::Sun
	    Astro::Coord::ECI::Moon
	    } ],
    );
}

sub _config_almanac_var_language {
    my ( $self, $name, $val ) = @_;
    my $rslt;
    $rslt = $self->SUPER::config( $name, $val )
	and return $rslt;

    my $attr = $self->_get_my_attr();
    my $lang = lc $val;

    exists $attr->{lang}
	and $lang eq $attr->{lang}
	and return $rslt;

    my $mod = "Date::ManipX::Almanac::Lang::$Date::Manip::Lang::index::Lang{$lang}";
    Module::Load::load( $mod );	# Dies on error
    $attr->{lang}{lang}			= $lang;
    $attr->{lang}{mod}			= $mod;
    delete $attr->{lang}{obj};

    return $rslt;
}

sub _config_almanac_var_twilight {
    my ( $self, $name, $val ) = @_;
    my $attr = $self->_get_my_attr();

    my $set_val;
    if ( defined $val ) {
	if ( Astro::Coord::ECI::Utils::looks_like_number( $val ) ) {
	    $set_val = - Astro::Coord::ECI::Utils::deg2rad( abs $val );
	} else {
	    defined( $set_val = $self->_get_twilight_qual( $val ) )
		or return $self->_my_config_err(
		"Do not recognize '$val' twilight" );
	}
    }

    $attr->{config}{twilight} = $val;
    $attr->{config}{_twilight} = $set_val;
    $attr->{config}{location}
	and $attr->{config}{location}->set( $name => $set_val );

    return;
}

sub _config_var_is_eci {
    my ( undef, undef, $val ) = @_;
    ref $val
	and Scalar::Util::blessed( $val )
	and $val->isa( 'Astro::Coord::ECI' )
	or return;
    return $val;
}

# This ought to be in Astro::Coord::ECI::Utils
sub _hms2rad {
    my ( $hms ) = @_;
    my ( $hr, $min, $sec ) = split qr < : >smx, $hms;
    $_ ||= 0 for $sec, $min, $hr;
    return TWOPI * ( ( ( $sec / 60 ) + $min ) / 60 + $hr ) / 24;
}

sub _config_var_is_eci_class {
    my ( $self, $name, $val ) = @_;
    my $rslt;
    $rslt = $self->_config_var_is_eci( $name, $val )
	and return $rslt;
    if ( ! ref $val ) {
	my ( $class, @arg ) = split qr/ \s+ /smx, $val;
	Module::Load::load( $class );
	state $factory = {
	    'Astro::Coord::ECI::Star'	=> sub {
		my ( $name, $ra, $decl, $rng ) = @_;
		return Astro::Coord::ECI::Star->new(
		    name	=> $name,
		)->position(
		    _hms2rad( $ra ),
		    Astro::Coord::ECI::Utils::deg2rad( $decl ),
		    $rng,
		);
	    },
	};
	my $code = $factory->{$class} || sub { $class->new() };
	my $obj = $code->( @arg );
	if ( $rslt = $self->_config_var_is_eci( $name, $obj ) ) {
	    return $rslt;
	}
    }
    $self->_my_config_err(
	"$val must be an Astro::Coord::ECI object or class" );
    return;
}

sub _config_almanac_var_location {
    my ( $self, $name, $val ) = @_;
    my $loc;
    if ( ! defined $val ) {
	$loc = undef;
    } elsif ( REF_HASH eq ref $val ) {
	defined $val->{latitude}
	    and defined $val->{longitude}
	    or return $self->_my_config_err(
	    'Location hash must specify both latitude and longitude' );
	$loc = Astro::Coord::ECI->new();
	defined $val->{name}
	    and $loc->set( name => $val->{name} );
	$loc->geodetic(
	    Astro::Coord::ECI::Utils::deg2rad( $val->{latitude} ),
	    Astro::Coord::ECI::Utils::deg2rad( $val->{longitude} ),
	    ( $val->{elevation} || 0 ) / METERS_PER_KILOMETER,
	);
    } else {
	$loc = $self->_config_var_is_eci_class( $name, $val )
	    or return 1;
    }

    my $attr = $self->_get_my_attr();
    defined $attr->{config}{_twilight}
	and $loc->set( twilight => $attr->{config}{_twilight} );
    foreach my $obj ( @{ $attr->{config}{sky} } ) {
	$obj->set( station => $loc );
    }
    $attr->{config}{location} = $loc;
    return;
}

sub _config_almanac_var_sky {
    my ( $self, $name, $values ) = @_;
    my $attr = $self->_get_my_attr();

    ref $values
	or $values = [ $values ];

    my @sky;
    foreach my $val ( @{ $values } ) {
	my $body = $self->_config_var_is_eci_class( $name, $val )
	    or return 1;
	push @sky, $body;
	$attr->{config}{location}
	    and $sky[-1]->set(
		station => $attr->{config}{location} );
    }

    @{ $attr->{config}{sky} } = @sky;
    delete $attr->{lang}{obj};

    return;
}

# NOTE encapsulation violation.
# I suppose I could get around this by implementing my attributes as an
# inside-out object, or implementing the Date::Manip functionality as
# "has-a" rather than "is-a".
sub _get_my_attr {
    my ( $self ) = @_;
    return ( $self->{ +__PACKAGE__ } ||= {} );
}

sub _get_twilight_qual {
    my ( undef, $qual ) = @_;	# Invocant not used
    defined $qual
	or return $qual;
    state $twi_name = {
	civil		=> Astro::Coord::ECI::Utils::deg2rad( -6 ),
	nautical	=> Astro::Coord::ECI::Utils::deg2rad( -12 ),
	astronomical	=> Astro::Coord::ECI::Utils::deg2rad( -18 ),
    };
    return $twi_name->{ lc $qual };
}

sub _init_almanac {
    my ( $self, $from ) = @_;
    if ( Scalar::Util::blessed( $from ) && $from->isa( __PACKAGE__ ) ) {
	state $cfg_var = [ qw{ language location sky twilight } ];
	my %cfg;
	@cfg{ @{ $cfg_var } } = $from->get_config( @{ $cfg_var } );
	# We clone because these objects have state.
	# TODO this requires at least 0.118_01.
	@{ $cfg{sky} } = map { $_->clone() } @{ $cfg{sky} };
	$self->config( %cfg );
    } else {
	$self->_init_almanac_language( 1 );
	if ( my $lang = $self->get_config( 'language' ) ) {
	    $self->_config_almanac_var_language( language => $lang );
	}
	my $attr = $self->_get_my_attr();
	%{ $attr->{config} } = ();
    }
    return;
}

sub _init_almanac_language {
    my ( $self, $force ) = @_;

    my $attr = $self->_get_my_attr();
    not $force
	and exists $attr->{lang}
	and return;

    $attr->{lang}		= {};

    return;
}

sub _my_config_err {
    my ( undef, $err ) = @_;
    warn "ERROR: [config_var] $err\n";
    return 1;
}

sub __parse_pre {
    my ( $self, $string ) = @_;
    wantarray
	or confess 'Bug - __parse_pre() must be called in list context';
    my $attr = $self->_get_my_attr();
    delete $attr->{err};
    @{ $attr->{config}{sky} || [] }
	or return $string;

    $attr->{lang}{obj} ||= $attr->{lang}{mod}->__new(
	sky		=> $attr->{config}{sky},
    );
    return $attr->{lang}{obj}->__parse_pre( $string );
}

sub __parse_post {
    my ( $self, $body, $event, undef ) = @_;
    defined $body
	and defined $event
	or return;

    my $attr = $self->_get_my_attr();
    $attr->{config}{location}
	or return $self->_set_err( "[parse] Location not configured" );

    my $code = $self->can( "__parse_post__$event" )
	or confess "Bug - event $event not implemented";

    # TODO support for systems that do not use this epoch.
    $body->universal( $self->secs_since_1970_GMT() );

    goto $code;
}

sub _set_err {
    my ( $self, $err ) = @_;
    my $attr = $self->_get_my_attr();

    $attr->{err} = $err;
    return 1;
}

sub __parse_post__horizon {
    my ( $self, $body, undef, $detail ) = @_;

    my $almanac_horizon = $body->get( 'station' )->get(
	'almanac_horizon' );

    my ( $time, $which );
    while ( 1 ) {
	( $time, $which ) = $body->next_elevation( $almanac_horizon, 1 );
	$which == $detail
	    and last;
    }

    $self->secs_since_1970_GMT( $time );

    return;
}

sub __parse_post__meridian {
    my ( $self, $body, undef, $detail ) = @_;

    my ( $time, $which );
    while ( 1 ) {
	( $time, $which ) = $body->next_meridian();
	$which == $detail
	    and last;
    }

    $self->secs_since_1970_GMT( $time );

    return;
}

sub __parse_post__quarter {
    my ( $self, $body, undef, $detail ) = @_;

    my $time = $body->next_quarter( $detail );

    $self->secs_since_1970_GMT( $time );

    return;
}

sub __parse_post__twilight {
    my ( $self, $body, undef, $detail, $qual ) = @_;

    my $station = $body->get( 'station' );
    my $twilight = $station->get( 'almanac_horizon' ) + (
	$self->_get_twilight_qual( $qual ) // $station->get( 'twilight' ) );

    my ( $time, $which );
    while ( 1 ) {
	( $time, $which ) = $body->next_elevation( $twilight, 0 );
	$which == $detail
	    and last;
    }

    $self->secs_since_1970_GMT( $time );

    return;
}

1;

__END__

=head1 NAME

Date::ManipX::Almanac::Date - Methods for working with almanac dates

=head1 SYNOPSIS

 use Date::ManipX::Almanac::Date
 
 my $dmad = Date::ManipX::Almanac::Date->new();
 $dmad->config(
   location => {
     latitude  =>  38.8987,     # Degrees; south is negative
     longitude => -77.0377,     # Degrees; west is negative
     elevation =>  17,          # Meters, defaults to 0
     name      =>  'White House', # Optional
   },
 );
 $dmad->parse( 'sunrise today' );
 $dmad->printf( 'Sunrise on %d-%b-%Y is %H:%M:%S' );

=head1 DESCRIPTION

This Perl module implements a subclass of
L<Date::Manip::Date|Date::Manip::Date> that understands a selection of
almanac events. These are implemented using the relevant
L<Astro::Coord::ECI|Astro::Coord::ECI> classes.

B<Note> that most almanac calculations are for a specific point on the
Earth's surface. It would be nice to default this via the computer's
geolocation API, but for at least the immediate future you must specify
it explicitly. Failure to do this will result in an exception from
L<parse()|/parse> or L<parse_time()|/parse_time> if an almanac event was
actually specified.

The functional interface to L<Date::Manip::Date|Date::Manip::Date> is
not implemented.

=head1 METHODS

This class provides no public methods of its own, but overrides the
following L<Date::Manip::Date|Date::Manip::Date> methods.

=head2 new

 my $dmad = Date::ManipX::Almanac::Date->new();

The arguments are the same as the superclass arguments, but
L<CONFIGURATION|/CONFIGURATION> items specific to this class are
supported.

=head2 config

 my $err = $dmad->config( ... );

All superclass arguments are supported, plus those described under
L<CONFIGURATION|/CONFIGURATION>, below.

=head2 err

This method returns a description of the most-recent error, or a false
value if there is none. Errors detected in this package trump those in
the superclass.

=head2 get_config

 my @config = $dmad->get_config( ... );

All superclass arguments are supported, plus those described under
L<CONFIGURATION|/CONFIGURATION>, below.

=head2 parse

 my $err = $dmad->parse( 'today sunset' );

All superclass arguments are supported, plus those described under
L<ALMANAC EVENTS|Date::ManipX::Almanac::Lang/ALMANAC EVENTS> in
L<Date::ManipX::Almanac::Lang|Date::ManipX::Almanac::Lang>.

=head2 parse_time

 my $err = $dmad->parse_time( 'sunset' );

All superclass arguments are supported, plus those described under
L<ALMANAC EVENTS|Date::ManipX::Almanac::Lang/ALMANAC EVENTS> in
L<Date::ManipX::Almanac::Lang|Date::ManipX::Almanac::Lang>.

=head1 CONFIGURATION

This class uses the L<Date::Manip|Date::Manip> C<config()> interface,
but adds or modifies the following configuration items:

=head2 ConfigFile

This class adds section C<*almanac>. The following items may be
specified in that section:

=over

=item elevation

This is the elevation above sea level of the location, in meters. If
omitted, it defaults to C<0>.

=item latitude

This is the latitude of the location in decimal degrees. Latitudes south
are negative.

=item longitude

This is the longitude of the location in decimal degrees. Longitudes west
are negative.

=item name

This is the name of the location. It is optional, and is unused by this
package.

=item sky

This specifies the class name of an astronomical body to be included in
the almanac. It can be specified more than once, so

 sky = Astro::Coord::ECI::Sun
 sky = Astro::Coord::ECI::Moon

specifies that both Sun and Moon be included.

In general, only classes that can fully initialize themselves will work
here. There is special-case code for
L<Astro::Coord::ECI::Star|Astro::Coord::ECI::Star>, though, that lets
you specify the name of the star, its right ascension (in
hours:minutes:seconds) and declination (in decimal degrees), and
optionally its distance in parsecs. So you can configure (for example)

 sky = Astro::Coord::ECI::Star Arcturus 14:15:39.67207 +19.182409

=item twilight

This specifies how far the Sun is below the horizon at the beginning or
end of twilight. You can specify this in degrees, or as one of the
following strings for convenience: C<'civil'> (6 degrees); C<'nautical'>
(12 degrees); or C<'astronomical'> (18 degrees).

The default is civil twilight.

=back

=head2 Defaults

In addition to its action on the superclass, this clears the location,
and populates the sky with
L<Astro::Coord::ECI::Sun|Astro::Coord::ECI::Sun> and
L<Astro::Coord::ECI::Moon|Astro::Coord::ECI::Moon>.

=head2 Language

In addition to its action on the superclass, this loads the almanac
event definitions for the specified language. B<Note> that this will
fail unless a L<Date::ManipX::Almanac::Lang|Date::ManipX::Almanac::Lang>
subclass has been implemented for the language.

=head2 Location

This specifies the location for which to compute the almanac. This can
be specified as:

=over

=item an Astro::Coord::ECI object

=item a hash reference

This hash must contain keys C<latitude> and C<longitude> (in decimal
degrees, with south and west negative). It may also contain keys
C<elevation> (in meters, defaulting to C<0>) and C<name> (set, but
unused by this package).

=item undef

This clears the location.

=back

=head2 sky

This is a reference to an array containing zero or more class names or
instantiated objects. These replace whatever objects were previously
configured.

=head1 SEE ALSO

L<Date::Manip::Date|Date::Manip::Date>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Date-ManipX-Astro-Base>,
L<https://github.com/trwyant/perl-Date-ManipX-Astro-Base/issues/>, or in
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
