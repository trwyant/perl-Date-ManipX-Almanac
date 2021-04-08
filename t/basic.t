package main;

use strict;
use warnings;

use Test2::V0;
use Test2::Plugin::BailOnFail;
use Test2::Tools::LoadModule;

load_module_ok 'Date::ManipX::Almanac::Lang';

load_module_ok 'Date::ManipX::Almanac::Lang::english';

SKIP: {
    $ENV{AUTHOR_TESTING}
	or skip 'Date::ManipX::Almanac::Lang::spanish is unpublished', 1;
    load_module_ok 'Date::ManipX::Almanac::Lang::spanish';
}

load_module_ok 'Date::ManipX::Almanac::Date';

{
    my $obj = eval { Date::ManipX::Almanac::Date->new() };
    isa_ok $obj, 'Date::ManipX::Almanac::Date';
}

load_module_ok 'Date::ManipX::Almanac';

done_testing;

1;
