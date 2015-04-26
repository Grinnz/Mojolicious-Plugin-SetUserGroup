use strict;
use warnings;
use Test::More;
use Mojo::IOLoop;
use Mojo::JSON 'encode_json', 'decode_json';
use Mojo::Server::Daemon;
use POSIX qw(geteuid getgid);
use Unix::Groups 'getgroups';

plan skip_all => 'TEST_RUN_SUDO=1' unless $ENV{TEST_RUN_SUDO};
if ((my $uid = geteuid()) != 0) {
	my $user = getpwuid $uid;
	my $gid = getgrnam $user;
	my $groups = [getgroups()];
	$ENV{TEST_ORIGINAL_USER} = encode_json {user => $user, uid => $uid, gid => $gid, groups => $groups};
	exec 'sudo', '-nE', $^X, '-I', $INC[0], $0, @ARGV;
}

my $original = decode_json($ENV{TEST_ORIGINAL_USER} || '{}');
plan skip_all => "user is missing in TEST_ORIGINAL_USER=$ENV{TEST_ORIGINAL_USER}"
	unless my $user = delete $original->{user};

my $daemon = Mojo::Server::Daemon->new(listen => ['http://127.0.0.1'], silent => 1);
$daemon->app->plugin(SetUserGroup => {user => $user, group => $user});
$daemon->start;
$daemon->app->routes->children([]);
$daemon->app->routes->get('/' => sub {
	shift->render(json => {
		uid => geteuid(),
		gid => getgid(),
		groups => [getgroups()],
	});
});
my $port = Mojo::IOLoop->acceptor($daemon->acceptors->[0])->port;
my $buffer = '';
Mojo::IOLoop->client({port => $port}, sub {
	my ($loop, $err, $stream) = @_;
	$stream->on(read => sub { $buffer .= $_[1]; Mojo::IOLoop->stop if $buffer =~ m/\}/ });
	$stream->write("GET / HTTP/1.1\x0d\x0a\x0d\x0a");
});

Mojo::IOLoop->start;
$buffer =~ s!.*\x0d\x0a!!s;
my $response = decode_json($buffer);
my $orig_groups = delete $original->{groups};
my $new_groups = delete $response->{groups};
is_deeply($response, $original, 'UID and GID match') or diag $buffer;

my %check_groups = map { ($_ => 1) } @$new_groups;
my $is_in_groups = 1;
foreach my $gid (@$orig_groups) {
	$is_in_groups = 0 unless exists $check_groups{$gid};
}
ok $is_in_groups, "User is in all original secondary groups";
%check_groups = map { ($_ => 1) } @$orig_groups;
$is_in_groups = 1;
foreach my $gid (@$new_groups) {
	$is_in_groups = 0 unless $gid == $response->{gid} or exists $check_groups{$gid};
}
ok $is_in_groups, "All secondary groups are assigned to user";

done_testing;
