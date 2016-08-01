use strict;
use warnings;
use Test::More;
use File::Temp;
use Mojo::IOLoop;
use Mojo::Server::Daemon;
use Mojo::Util 'slurp';
use POSIX 'geteuid', 'getegid';

plan skip_all => 'Non-root test' if geteuid() == 0;

my $uid = geteuid();
my $gid = getegid();
my $user = getpwuid 0;
my $group = getgrgid 0;

plan skip_all => 'User 0 does not exist' unless defined $user;
plan skip_all => 'Group 0 does not exist' unless defined $group;

my $templog = File::Temp->new;
my $daemon = Mojo::Server::Daemon->new(listen => ['http://127.0.0.1'], silent => 1);
$daemon->app->log->path($templog->filename);
$daemon->app->plugin(SetUserGroup => {user => $user, group => $group});

defined(my $pid = fork) or die "Fork failed: $!";

unless ($pid) {
	Mojo::IOLoop->timer(0.5 => sub { $daemon->app->log->error("Test server has started"); Mojo::IOLoop->stop });
	{ open my $null, '>', '/dev/null'; local *STDERR = $null; $daemon->run; }
	exit 0;
}
waitpid $pid, 0;

my $log = slurp $templog->filename;
unlike $log, qr/Test server has started/, 'Server failed to start';
like $log, qr/Can't (switch to (user|group)|set supplemental groups)/, 'right error';
cmp_ok geteuid(), '==', $uid, 'User has not changed';
cmp_ok getegid(), '==', $gid, 'Group has not changed';

done_testing;
