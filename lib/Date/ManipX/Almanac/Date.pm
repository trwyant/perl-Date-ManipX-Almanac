package Date::ManipX::Almanac::Date;

use 5.010;

use strict;
use warnings;

use Astro::Coord::ECI 0.119;	# For clone() to work.
use Astro::Coord::ECI::Utils 0.119 qw{ TWOPI };
use Carp;
use Date::Manip::Date;
use Module::Load ();
use Scalar::Util ();

our $VERSION = '0.000_003';

use constant REF_ARRAY	=> ref [];
use constant REF_HASH	=> ref {};
use constant METERS_PER_KILOMETER	=> 1000;

sub new {
    my ( $class, @args ) = @_;
    return $class->_new( new => @args );
}

sub _new {
    my ( $class, $new_method, @args ) = @_;

    my @config;
    if ( @args && REF_ARRAY eq ref $args[-1] ) {
	@config = @{ pop @args };
	state $method_map = {
	    new	=> 'new_config',
	};
	$new_method = $method_map->{$new_method} // $new_method;
    }

    my ( $dmd, $from );
    if ( ref $class ) {
	$from = $class;
	$dmd = $class->dmd()->$new_method();
    } elsif ( Scalar::Util::blessed( $args[0] ) ) {
	$from = shift @args;
	$dmd = Date::Manip::Date->$new_method(
	    $from->isa( __PACKAGE__ ) ? $from->dmd() : $from
	);
    } else {
	$dmd = Date::Manip::Date->$new_method();
    }

    my $self = bless {
	dmd	=> $dmd,
    }, ref $class || $class;

    $self->_init_almanac( $from );

    @config
	and $self->config( @config );

    $self->get_config( 'sky' )
	or $self->_config_almanac_default_sky();

    @args
	and $self->parse( @args );

    return $self;
}

sub new_config {
    my ( $class, @args ) = @_;
    return $class->_new( new_config => @args );
}

sub new_date {
    my ( $class, @args ) = @_;
    # return $class->_new( new_date => @args );
    return $class->new( @args );
}

sub calc {
   my ( $self, $obj, @args ) = @_;
   Scalar::Util::blessed( $obj )
       and $obj->isa( __PACKAGE__ )
       and $obj = $obj->dmd();
   return $self->dmd()->calc( $obj, @args );
}

sub cmp : method {	## no critic (ProhibitBuiltinHomonyms)
   my ( $self, $date ) = @_;
   $date->isa( __PACKAGE__ )
       and $date = $date->dmd();
   return $self->dmd()->cmp( $date );
}

sub config {
    my ( $self, @arg ) = @_;

    delete $self->{err};

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
	    $self->dmd()->config( $name, $val );
	}
    }

    return;
}

sub dmd {
    my ( $self ) = @_;
    return $self->{dmd};
}

sub err {
    my ( $self ) = @_;
    return $self->{err} // $self->dmd()->err();
}

sub get_config {
    my ( $self, @arg ) = @_;
    delete $self->{err};
    my @rslt;

    foreach my $name ( @arg ) {
	state $mine = { map { $_ => 1 } qw{ location sky twilight } };
	push @rslt, $mine->{$name} ?
	    $self->{config}{$name} :
	    $self->dmd()->get_config( $name );
    }

    return 1 == @rslt ? $rslt[0] : @rslt;
}

sub input {
    my ( $self ) = @_;
    return $self->{input};
}

sub list_events {
   my ( $self, @args ) = @_;
   Scalar::Util::blessed( $args[0] )
       and $args[0]->isa( __PACKAGE__ )
       and $args[0] = $args[0]->dmd();
   return $self->dmd()->list_events( @args );
}

sub parse {
    my ( $self, $string ) = @_;
    my ( $idate, @event ) = $self->__parse_pre( $string );
    return $self->dmd()->parse( $idate ) || $self->__parse_post( @event );
}

sub parse_time {
    my ( $self, $string ) = @_;
    my ( $idate, @event ) = $self->__parse_pre( $string );
    return $self->dmd()->parse_time( $idate ) || $self->__parse_post( @event );
}

sub _config_almanac_configfile {
    # my ( $self, $name, $val ) = @_;
    my ( $self, undef, $val ) = @_;
    my $rslt;
    my @almanac;
    {
	my $tz = $self->dmd()->tz();
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
    %{ $self->{config} } = ();
    delete $self->{lang};
    my $rslt = $self->dmd()->config( $name, $val ) ||
	$self->_config_almanac_default_sky() ||
	$self->_config_almanac_var_language( language => 'english' ) ||
	$self->_config_almanac_var_twilight( twilight => 'civil' );
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
    $rslt = $self->dmd()->config( $name, $val )
	and return $rslt;

    my $lang = lc $val;

    exists $self->{lang}
	and $lang eq $self->{lang}
	and return $rslt;

    my $mod = "Date::ManipX::Almanac::Lang::$lang";
    __load_module( $mod );	# Dies on error
    $self->{lang}{lang}			= $lang;
    $self->{lang}{mod}			= $mod;
    delete $self->{lang}{obj};

    return $rslt;
}

# We do this circumlocution so we can hook during testing if need be.
*__load_module = Module::Load->can( 'load' );

sub _config_almanac_var_twilight {
    my ( $self, $name, $val ) = @_;

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

    $self->{config}{twilight} = $val;
    $self->{config}{_twilight} = $set_val;
    $self->{config}{location}
	and $self->{config}{location}->set( $name => $set_val );

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

    defined $self->{config}{_twilight}
	and defined $loc
	and $loc->set( twilight => $self->{config}{_twilight} );
    foreach my $obj ( @{ $self->{config}{sky} } ) {
	$obj->set( station => $loc );
    }
    $self->{config}{location} = $loc;

    # NOTE we do this because when the Lang object initializes itself it
    # consults the first sky object's station attribute (set above) to
    # figure out whether it is in the Northern or Southern hemisphere.
    # The object will be re-created when we actually try to perform a
    # parse.
    delete $self->{lang}{obj};

    return;
}

sub _config_almanac_var_sky {
    my ( $self, $name, $values ) = @_;

    ref $values
	or $values = [ $values ];

    my @sky;
    foreach my $val ( @{ $values } ) {
	my $body = $self->_config_var_is_eci_class( $name, $val )
	    or return 1;
	push @sky, $body;
	$self->{config}{location}
	    and $sky[-1]->set(
		station => $self->{config}{location} );
    }

    @{ $self->{config}{sky} } = @sky;

    # NOTE we do this to force re-creation of the Lang object, which
    # then picks up the new sky.
    delete $self->{lang}{obj};

    return;
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
	%{ $self->{config} } = ();
    }
    return;
}

sub _init_almanac_language {
    my ( $self, $force ) = @_;

    not $force
	and exists $self->{lang}
	and return;

    $self->{lang}		= {};

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
    delete $self->{err};
    $self->{input} = $string;
    @{ $self->{config}{sky} || [] }
	or return $string;

    $self->{lang}{obj} ||= $self->{lang}{mod}->__new(
	sky		=> $self->{config}{sky},
    );
    return $self->{lang}{obj}->__parse_pre( $string );
}

sub __parse_post {
    my ( $self, $body, $event, undef ) = @_;
    defined $body
	and defined $event
	or return;

    $self->{config}{location}
	or return $self->_set_err( "[parse] Location not configured" );

    my $code = $self->can( "__parse_post__$event" )
	or confess "Bug - event $event not implemented";

    $DB::single = 1;	# Debug

    # TODO support for systems that do not use this epoch.
    $body->universal( $self->secs_since_1970_GMT() );

    goto $code;
}

sub _set_err {
    my ( $self, $err ) = @_;

    $self->{err} = $err;
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

# Implemented as a subroutine so I can authortest for changes. This was
# the list as of Date::Manip::Date version 6.85. The list is generated
# by tools/dmd_public_interface.
sub __date_manip_date_public_interface {
    return ( qw{
	base
	calc
	cmp
	complete
	config
	convert
	err
	get_config
	holiday
	input
	is_business_day
	is_date
	is_delta
	is_recur
	list_events
	list_holidays
	nearest_business_day
	new
	new_config
	new_date
	new_delta
	new_recur
	next
	next_business_day
	parse
	parse_date
	parse_format
	parse_time
	prev
	prev_business_day
	printf
	secs_since_1970_GMT
	set
	tz
	value
	version
	week_of_year
    } );
}

# NOTE encapsulation violation: _init is not part of the public
# interface, but is used in the Date::Manip test suite.
foreach my $method ( qw{
	_init
	}, __date_manip_date_public_interface(),
) {
    __PACKAGE__->can( $method )
	and next;
    Date::Manip::Date->can( $method )
	or next;
    no strict qw{ refs };
    *$method = sub {
	my ( $self, @arg ) = @_;
	return $self->dmd()->$method( @arg );
    };
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

This Perl module implements a version of
L<Date::Manip::Date|Date::Manip::Date> that understands a selection of
almanac events. These are implemented using the relevant
L<Astro::Coord::ECI|Astro::Coord::ECI> classes.

This module is B<not> an actual subclass of
L<Date::Manip::Date|Date::Manip::Date>, but holds a C<Date::Manip::Date>
object to perform a lot of the heavy lifting, and implements all its
public methods, usually by delegating directly to C<Date::Manip::Date>.
This implementation was chosen because various portions of the
C<Date::Manip::Date> interface want an honest-to-God
C<Date::Manip::Date> object, not a subclass. The decision to implement
this way may be revisited if the situation warrants.

In the meantime, be aware that if you are doing something like
instantiating a L<Date::Manip::TZ|Date::Manip::TZ> from this object, you
will have to use C<< $dmad->dmd() >>, not C<$dmad>.

B<Note> that most almanac calculations are for a specific point on the
Earth's surface. It would be nice to default this via the computer's
geolocation API, but for at least the immediate future you must specify
it explicitly. Failure to do this will result in an exception from
L<parse()|/parse> or L<parse_time()|/parse_time> if an almanac event was
actually specified.

The functional interface to L<Date::Manip::Date|Date::Manip::Date> is
not implemented.

=head1 METHODS

This class provides the following public methods which are either in
addition to those provided by L<Date::Manip::Date|Date::Manip::Date> or
provide additional functionality. Any C<Date::Manip::Date> methods not
mentioned below should Just Work.

=head2 new

 my $dmad = Date::ManipX::Almanac::Date->new();

The arguments are the same as the L<Date::Manip::Date|Date::Manip::Date>
C<new()> arguments, but L<CONFIGURATION|/CONFIGURATION> items specific
to this class are supported.

=head2 new_date

 my $dmad_2 = $dmad->new_date();

The arguments are the same as the L<Date::Manip::Date|Date::Manip::Date>
C<new_date()> arguments, but L<CONFIGURATION|/CONFIGURATION> items
specific to this class are supported.

=head2 new_config

 my $dmad = Date::ManipX::Almanac::Date->new_config();

The arguments are the same as the L<Date::Manip::Date|Date::Manip::Date>
C<new_config()> arguments, but L<CONFIGURATION|/CONFIGURATION> items
specific to this class are supported.

=head2 calc

If the first argument is a C<Date::ManipX::Almanac::Date> object, it is
replaced by the underlying C<Date::Manip::Date> object.

=head2 cmp

If the first argument is a C<Date::ManipX::Almanac::Date> object, it is
replaced by the underlying C<Date::Manip::Date> object.

=head2 config

 my $err = $dmad->config( ... );

All L<Date::Manip::Date|Date::Manip::Date> arguments are supported, plus
those described under L<CONFIGURATION|/CONFIGURATION>, below.

=head2 dmd

 my $dmd = $dmad->dmd();

This method returns the underlying
L<Date::Manip::Date|Date::Manip::Date> object.

=head2 err

This method returns a description of the most-recent error, or a false
value if there is none. Errors detected in this package trump those in
L<Date::Manip::Date|Date::Manip::Date>.

=head2 get_config

 my @config = $dmad->get_config( ... );

All L<Date::Manip::Date|Date::Manip::Date> arguments are supported, plus
those described under L<CONFIGURATION|/CONFIGURATION>, below.

=head2 parse

 my $err = $dmad->parse( 'today sunset' );

All L<Date::Manip::Date|Date::Manip::Date> strings are supported, plus
those described under L<ALMANAC
EVENTS|Date::ManipX::Almanac::Lang/ALMANAC EVENTS> in
L<Date::ManipX::Almanac::Lang|Date::ManipX::Almanac::Lang>.

=head2 parse_time

 my $err = $dmad->parse_time( 'sunset' );

All L<Date::Manip::Date|Date::Manip::Date> strings are supported, plus
those described under L<ALMANAC
EVENTS|Date::ManipX::Almanac::Lang/ALMANAC EVENTS> in
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
