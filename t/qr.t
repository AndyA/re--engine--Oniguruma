use Test::More tests => 2;
use re::engine::Oniguruma;

my $re = qr/aoeu/;

isa_ok($re, "re::engine::Oniguruma");
is("$re", "aoeu");
