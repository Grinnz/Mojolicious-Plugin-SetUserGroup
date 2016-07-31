use strict;
use warnings;
use Test::More;
use Mojo::IOLoop;
use Mojo::Server::Daemon;
use POSIX 'geteuid', 'getegid';

plan skip_all => 'Non-root test' if geteuid() == 0;

open my $log_handle, '>', \my $log_buffer;
open my $null, '>', '/dev/null';

my $uid = geteuid();
my $gid = getegid();
my $user = getpwuid 0;
my $group = getgrgid 0;

try_server($user, $group, qr/Can't (switch to (user|group)|set supplemental groups)/);

sub try_server {
	my ($user, $group, $re) = @_;
	$log_buffer = '';
	my $daemon = Mojo::Server::Daemon->new(listen => ['http://127.0.0.1'], silent => 1);
	$daemon->app->plugin(SetUserGroup => {user => $user, group => $group});
	$daemon->app->log->handle($log_handle);
	$daemon->start;
	my $failed = 1;
	Mojo::IOLoop->timer(0.5 => sub { $failed = 0; Mojo::IOLoop->stop });
	{
		local *STDERR = $null;
		Mojo::IOLoop->start;
	}
	ok $failed, 'Server has failed to start';
	like $log_buffer, $re, 'right error' if $re;
	cmp_ok geteuid(), '==', $uid, 'User has not changed';
	cmp_ok getegid(), '==', $gid, 'Group has not changed';
}

done_testing;
