use strict;
use warnings;
use Test::More;
use Mojo::IOLoop;
use Mojo::Log;
use Mojo::Server::Daemon;
use POSIX 'geteuid';

open my $log_handle, '>', \my $log_buffer;
open STDERR, '>/dev/null';

my $i = 0;
my $invalid = 'invalid';
until (!defined getpwnam $invalid and !defined getgrnam $invalid) {
	$invalid = 'invalid'.$i++;
}

my $user = getpwuid geteuid();

try_server($invalid, $invalid, qr/User "$invalid" does not exist/);
try_server($user, $invalid, qr/Group "$invalid" does not exist/);

unless (geteuid() == 0) { # Root user will not fail
	try_server($user, $user, qr/Can't (switch to (user|group)|set supplemental GIDs)/);
}

sub try_server {
	my ($user, $group, $re) = @_;
	$log_buffer = '';
	my $daemon = Mojo::Server::Daemon->new(listen => ['http://127.0.0.1'], silent => 1);
	$daemon->app->plugin(SetUserGroup => {user => $user, group => $group});
	$daemon->app->log->handle($log_handle);
	$daemon->start;
	my $failed = 1;
	Mojo::IOLoop->timer(0.5 => sub { $failed = 0; Mojo::IOLoop->stop });
	Mojo::IOLoop->start;
	ok $failed, 'Server has failed to start';
	like $log_buffer, $re, 'right error' if $re;
}

done_testing;
