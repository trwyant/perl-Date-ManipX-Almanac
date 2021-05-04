package main;

use 5.010;

use strict;
use warnings;

use Astro::Coord::ECI 0.119;
use Astro::Coord::ECI::Utils 0.119 qw{ deg2rad rad2deg };
use Test2::V0 -target => 'Date::ManipX::Almanac::Date';

use lib qw{ inc };
use My::Module::Test;

use constant METERS_PER_KILOMETER	=> 1000;

my $loc = Astro::Coord::ECI->new(
    name	=> 'White House',
)->geodetic(
    deg2rad( 38.8987 ),
    deg2rad( -77.0377 ),
    17 / METERS_PER_KILOMETER,
);

my $dmad = CLASS->new();

foreach my $station (
    $loc,
    {
	latitude	=> 38.8987,	# South is negative
	longitude	=> -77.0377,	# West is negative
	elevation	=> 17,	# Meters
	name		=> 'White House',
    },
) {
    note 'Configure location with ', ref $station;
    $dmad->config( location => $station );

    my $got_loc = $dmad->get_config( 'location' );
    isa_ok $got_loc, ref $loc;
    is [ $got_loc->geodetic() ], [ $loc->geodetic() ], 'Correct location';
}

my $sky = $dmad->get_config( 'sky' );
is scalar @{ $sky }, 2, 'Sky contains two bodies';
isa_ok $sky->[0], 'Astro::Coord::ECI::Sun';
isa_ok $sky->[1], 'Astro::Coord::ECI::Moon';

ok !$dmad->config( sky => [] ), 'Attempt to clear the sky succeeded';
is scalar @{ $dmad->get_config( 'sky' ) }, 0, 'Cleared the sky';

ok ! $dmad->config( defaults => 1 ), 'config( defaults => 1 )';
$sky = $dmad->get_config( 'sky' );
is scalar @{ $sky }, 2, 'Sky contains two bodies';
isa_ok $sky->[0], 'Astro::Coord::ECI::Sun';
isa_ok $sky->[1], 'Astro::Coord::ECI::Moon';

ok !$dmad->config( location => undef ), 'Attempt to clear location succeeded';
is $dmad->get_config( 'location' ), undef, 'Cleared the location';
ok !$dmad->config( sky => [] ), 'Attempt to clear the sky succeeded';
is scalar @{ $dmad->get_config( 'sky' ) }, 0, 'Cleared the sky';

ok ! $dmad->config( ConfigFile => TEST_CONFIG_FILE ),
    qq{config( ConfigFile => '@{[ TEST_CONFIG_FILE ]}' )};
$sky = $dmad->get_config( 'sky' );
if ( NO_STAR ) {
    is scalar @{ $sky }, 2, 'Sky contains two bodies';
} else {
    is scalar @{ $sky }, 3, 'Sky contains three bodies';
}
isa_ok $sky->[0], 'Astro::Coord::ECI::Sun';
isa_ok $sky->[1], 'Astro::Coord::ECI::Moon';

SKIP: {
    NO_STAR
	and skip NO_STAR, 2;
    isa_ok $sky->[2], 'Astro::Coord::ECI::Star';
    is $sky->[2]->get( 'name' ), 'Arcturus',
	'Third astronomical body is Arcturus';
}

{
    my $dmad2 = $dmad->new();
    ok $dmad2, 'Instantiate new object from old';
    isa_ok $dmad2, ref $dmad;
    my $loc2 = $dmad2->get_config( 'location' );
    isa_ok $loc2, ref $loc;
    is [ $loc2->geodetic() ], [ $loc->geodetic() ], 'Correct location';
    my $sky2 = $dmad2->get_config( 'sky' );
    isa_ok $sky2->[$_], ref $sky->[$_] for 0 .. $#$sky;
}

is $dmad->get_config( 'twilight' ), undef, 'Default twilight is undef';
$dmad->config( twilight => 'civil' );
is $dmad->get_config( 'twilight' ), 'civil', q<Set twilight to 'civil'>;
# DANGER WILL ROBINSON!
# Encapsulation violation. This is NOT part of the public interface, and
# may be changed without warning.
is rad2deg( $dmad->{config}{_twilight} ), -6,
    q<Set correct twilight in radians>;

done_testing;

1;

# ex: set textwidth=72 :
