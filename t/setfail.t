use strict;
use warnings;
use Test::More;
use Mojo::IOLoop;
use Mojo::Log;
use Mojo::Server::Daemon;

my $user = getpwuid $<;

open my $log_handle, '>', \my $log_buffer;
open STDERR, '>/dev/null';

my $daemon = Mojo::Server::Daemon->new(listen => ['http://127.0.0.1'], silent => 1);
$daemon->app->plugin(SetUserGroup => {user => $user, group => $user});
$daemon->app->log->handle($log_handle);
$daemon->start;

my $failed = 1;
Mojo::IOLoop->timer(0.5 => sub { $failed = 0; Mojo::IOLoop->stop });

Mojo::IOLoop->start;

ok $failed, 'Server has failed to start';
like $log_buffer, qr/Can't (switch to (user|group)|set supplemental GIDs)/, 'right error';

done_testing;
