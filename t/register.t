#!perl

use strict;
use warnings;

use Mojolicious::Lite;
use Test::More tests => 2;

eval {
	plugin 'SetUserGroup' => {
		user  => 'bad user name !!!!!',
	};
};

my $error = $@;
like(
	$error,
	qr/User "bad user name !!!!!" does not exist/,
	'plugin croaks on bad user at register'
);

eval {
	plugin 'SetUserGroup' => {
		user  => (getpwuid($<))[0],
		group => 'bad group name !!!!!',
	};
};

$error = $@;
like(
	$error,
	qr/Group "bad group name !!!!!" does not exist/,
	'plugin croaks on bad user at register'
);
