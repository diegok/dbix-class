use strict;
use Test::More;
use Test::NoWarnings;

BEGIN {
	eval "use DBD::SQLite";
	plan $@ ? (skip_all => 'needs DBD::SQLite for testing') : (tests => 6);

    use lib 't/testlib';
    use Film;
    use Order;
}

Film->has_many(orders => 'Order');
Order->has_a(film => 'Film');

Film->create_test_film;

my $film = Film->retrieve('Bad Taste');
isa_ok $film => 'Film';

$film->add_to_orders({ orders => 10 });

my $bto = (Order->search(film => 'Bad Taste'))[0];
isa_ok $bto => 'Order';
is $bto->orders, 10, "Correct number of orders";


my $infilm = $bto->film;
isa_ok $infilm, "Film";

is $infilm->id, $film->id, "Orders hasa Film";
