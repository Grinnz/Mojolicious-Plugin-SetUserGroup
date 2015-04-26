use Test::More;
use Mojolicious::Lite;
use Mojo::IOLoop;
use POSIX;

my $init_uid = POSIX::getuid();
my $init_gid = POSIX::getgid();
my $init_groups = $);

app->plugin(SetUserGroup => {});
Mojo::IOLoop->timer(0.5 => sub { Mojo::IOLoop->stop });

app->start;

is POSIX::getuid(), $init_uid, 'UID is unchanged';
is POSIX::getgid(), $init_gid, 'GID is unchanged';
is $), $init_groups, 'Groups are unchanged';

done_testing;
