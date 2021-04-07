package main;

use 5.010;

use strict;
use warnings;

use Astro::Coord::ECI;
use Astro::Coord::ECI::Utils qw{ deg2rad };
use Test2::V0 -target => 'Date::ManipX::Almanac::Date';

use lib qw{ inc };
use My::Module::Test;

BEGIN {
    local $@ = undef;
    use constant CLASS_VENUS	=> eval {
	require Astro::Coord::ECI::VSOP87D::Venus;
	'Astro::Coord::ECI::VSOP87D::Venus';
    }
}

my $dmad = CLASS->new( [ qw{
	ConfigFile t/data/white-house.config
	} ], );

$dmad->config(	# Redundant in this case, but not in another language
    language	=> 'English',
);

my $sky = $dmad->get_config( 'sky' );

subtest q<Parse 'today sunrise'> => sub {
    my ( $string, $body, $event, $detail ) = $dmad->__parse_pre( 'today sunrise' );
    is $string, 'today ', q<String became 'today '>;
    is $body, $sky->[0], q<Body is the Sun>;
    is $event, 'horizon', q<Event is 'horizon'>;
    is $detail, 1, q<Detail is 1>;
};

subtest q<Parse 'Moon sets'> => sub {
    my ( $string, $body, $event, $detail ) = $dmad->__parse_pre( 'Moon sets' );
    is $string, '00:00:00', q<String became '00:00:00'>;
    is $body, $sky->[1], q<Body is the Moon>;
    is $event, 'horizon', q<Event is 'horizon'>;
    is $detail, 0, q<Detail is 0>;
};

is parsed_value( $dmad, 'Sunset 2021-04-01' ), '2021040123:32:04',
    q<Time of Sunset April 1 2021>;

is parsed_value( $dmad, '2021-04-01 rising of the sun' ), '2021040110:52:21',
    q<Time of Sunrise April 1 2021>;

is parsed_value( $dmad, '2021-04-01 Moon culminates' ), '2021040108:26:53',
    q<Time of culmination of Moon April 1 2021>;

is parsed_value( $dmad, '2021-04-01 local noon' ), '2021040117:11:53',
    q<Local noon April 1 2021>;

is parsed_value( $dmad, 'end of twilight 2021-04-01' ), '2021040123:58:57',
    q<End of twilight April 1 2021>;

is parsed_value( $dmad, 'new moon 2021-04-01' ), '2021041202:30:21',
    q<First new moon on or after April 1 2021>;

is parsed_value( $dmad, 'summer solstice 2021' ), '2021062103:31:34',
    q<Summer solstice 2021>;

SKIP: {
    CLASS_VENUS
	or skip "@{[ CLASS_VENUS ]} not available";
    $dmad->config( sky => CLASS_VENUS );
    is parsed_value( $dmad, 'Venus rises 2021-04-01' ),
	'2021040111:03:14',
	q<Time of Venus rise April 1 2021>;
}


done_testing;

1;

# ex: set textwidth=72 :
