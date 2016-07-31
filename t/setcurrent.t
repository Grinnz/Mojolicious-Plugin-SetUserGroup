use strict;
use warnings;
use Test::More;
use Mojo::IOLoop;
use Mojo::Server::Daemon;
use POSIX 'geteuid', 'getegid';

plan skip_all => 'Non-root test' if geteuid() == 0;

my $uid = geteuid();
my $gid = getegid();
my $user = getpwuid $uid;
my $group = getgrgid $gid;

try_server($user, $group, qr/Can't (switch to (user|group)|set supplemental groups)/);

sub try_server {
	my ($user, $group, $re) = @_;
	my $daemon = Mojo::Server::Daemon->new(listen => ['http://127.0.0.1'], silent => 1);
	$daemon->app->plugin(SetUserGroup => {user => $user, group => $group});
	$daemon->start;
	my $failed = 1;
	Mojo::IOLoop->timer(0.1 => sub { $failed = 0; Mojo::IOLoop->stop });
	Mojo::IOLoop->start;
	ok !$failed, 'Server has started';
	cmp_ok geteuid(), '==', $uid, 'User has not changed';
	cmp_ok getegid(), '==', $gid, 'Group has not changed';
}

done_testing;
