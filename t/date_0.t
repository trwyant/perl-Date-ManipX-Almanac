package main;

use 5.010;

use strict;
use warnings;

use Astro::Coord::ECI;
use Astro::Coord::ECI::Utils qw{ deg2rad };
use Test2::V0 -target => 'Date::ManipX::Almanac::Date';

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
    note 'Configure with ', ref $station;
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

ok ! $dmad->config( ConfigFile => 't/data/white-house.config' ),
    q{config( ConfigFile => 't/data/white-house.config' )};
$sky = $dmad->get_config( 'sky' );
is scalar @{ $sky }, 2, 'Sky contains two bodies';
isa_ok $sky->[0], 'Astro::Coord::ECI::Sun';
isa_ok $sky->[1], 'Astro::Coord::ECI::Moon';

done_testing;

1;

# ex: set textwidth=72 :
