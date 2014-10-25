use strict;
use warnings;
use Test::More;
use Test::Exception;
use Data::Dumper;
no warnings 'once';

ok require Devel::DidYouMean;
throws_ok { Dumpr({ foo => 'bar' }) } qr/Dumper/, 'Imported sub';
is ${Devel::DidYouMean::DYM_MATCHING_SUB}, 'Dumper', 'Sets global matching function appropriately';
throws_ok { prnt('just a test') } qr/print/, 'builtin function';
throws_ok { Data::Dumper::Dumber({ foo => 'bar' }) } qr/Dumper/, 'Class sub';

done_testing();
