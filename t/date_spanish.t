package main;

use 5.010;

use strict;
use warnings;

use Astro::Coord::ECI 0.119;
use Astro::Coord::ECI::Moon 0.119;
use Astro::Coord::ECI::Sun 0.119;
use Astro::Coord::ECI::Utils 0.119 qw{ deg2rad };
use Test2::V0 -target => 'Date::ManipX::Almanac::Date';

use lib qw{ inc };
use My::Module::Test;

my $dmad = CLASS->new( [ AlmanacConfigFile => TEST_CONFIG_FILE ] );

$dmad->config(	# AlmanacConfigFile sets English
    language	=> 'Spanish',
);

my $sky = $dmad->get_config( 'sky' );

subtest q<Parse 'hoy a la salida del sol'> => sub {
    my ( $string, $body, $event, $detail ) = $dmad->__parse_pre(
	'hoy a la salida del sol' );
    is $string, 'hoy ', q<String became 'hoy '>;
    is $body, $sky->[0], q<Body is the Sun>;
    is $event, 'horizon', q<Event is 'horizon'>;
    is $detail, 1, q<Detail is 1>;
    is $dmad->input(), 'hoy a la salida del sol',
	q<Input was 'hoy a la salida del sol'>;
};

subtest q<Parse 'la puesta de la luna'> => sub {
    my ( $string, $body, $event, $detail ) = $dmad->__parse_pre(
	'la puesta de la luna' );
    is $string, '00:00:00', q<String became '00:00:00'>;
    is $body, $sky->[1], q<Body is the Moon>;
    is $event, 'horizon', q<Event is 'horizon'>;
    is $detail, 0, q<Detail is 0>;
    is $dmad->input(), 'la puesta de la luna',
	q<Input was 'la puesta de la luna'>;
};

subtest q<Parse 'la puesta del arcturus'> => sub {
    NO_STAR
	and skip_all NO_STAR;
    my ( $string, $body, $event, $detail ) =
	$dmad->__parse_pre( 'la puesta del arcturus' );
    is $string, '00:00:00', q<String became '00:00:00'>;
    is $body, $sky->[2], q<Body is Arcturus>;
    is $event, 'horizon', q<Event is 'horizon'>;
    is $detail, 0, q<Detail is 0>;
    is $dmad->input(), 'la puesta del arcturus',
	q<Input was 'la puesta del arcturus'>;
};

is parsed_value( $dmad, 'la puesta del sol 2021-04-01' ), '2021040123:32:04',
    q<Time of Sunset April 1 2021>;

is $dmad->tz()->zone(), 'America/New_York', q<Zone is America/New_York>;

is parsed_value( $dmad, '2021-04-01 a la salida del sol' ), '2021040110:52:21',
    q<Time of Sunrise April 1 2021>;

is parsed_value( $dmad, 'Crepusculo de la manana 2021-04-01' ),
    '2021040110:25:32',
    q<Time of Morning twilight 2021-04-01>;

is parsed_value( $dmad, 'Crepusculo astronomico de la manana 2021-04-01' ),
    '2021040109:21:15',
    q<Time of Morning astronomical twilight 2021-04-01>;

is parsed_value( $dmad, '2021-04-01 la luna es el mas alto' ),
    '2021040108:26:53',
    q<Time of culmination of Moon April 1 2021>;

is parsed_value( $dmad, '2021-04-01 a la mediodia local' ), '2021040117:11:53',
    q<Local noon April 1 2021>;

is parsed_value( $dmad, 'el crepusculo de la tarde 2021-04-01' ),
    '2021040123:58:57',
    q<End of twilight April 1 2021>;

is parsed_value( $dmad, 'la luna nueva 2021-04-01' ), '2021041202:30:21',
    q<First new moon on or after April 1 2021>;

is parsed_value( $dmad, 'el solsticio del verano 2021' ), '2021062103:31:34',
    q<Summer solstice 2021>;

is parsed_value( $dmad, 'el solsticio del verano despues de 2021-07-04' ),
    '2022062109:13:20',
    q<el solsticio del verano despues de 2021-07-04>;

SKIP: {
    NO_STAR
	and skip NO_STAR;
    is parsed_value( $dmad, 'la salida del Arcturus 2021-04-01' ),
	'2021040123:34:33',
	q<Arcturus rises 2021-04-01>;
}

SKIP: {
    NO_VENUS
	and skip NO_VENUS;
    $dmad->config( sky => CLASS_VENUS );
    is parsed_value( $dmad, 'la salida del Venus 2021-04-01' ),
	'2021040111:03:14',
	q<Time of Venus rise April 1 2021>;
}


done_testing;

1;

# ex: set textwidth=72 :
