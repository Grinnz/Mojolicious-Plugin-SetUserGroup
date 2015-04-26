package Mojolicious::Plugin::SetUserGroup;
use Mojo::Base 'Mojolicious::Plugin';

use List::Util 'any';
use Mojo::IOLoop;
use POSIX qw(setuid setgid);
use Unix::Groups 'setgroups';

our $VERSION = '0.001';

sub register {
	my ($self, $app, $conf) = @_;
	my $user = $conf->{user};
	my $group = $conf->{group} // $user;
	
	return $self unless defined $user;
	
	Mojo::IOLoop->next_tick(sub { _setusergroup($app, $user, $group) });
}

sub _error {
	my ($app, $error) = @_;
	chomp $error;
	$app->log->error($error);
	Mojo::IOLoop->stop;
}

sub _setusergroup {
	my ($app, $user, $group) = @_;
	
	# User
	_error($app, qq{User "$user" does not exist})
		unless defined(my $uid = getpwnam $user);
	
	# Group
	_error($app, qq{Group "$group" does not exist})
		unless defined(my $gid = getgrnam $group);
	
	# Secondary groups
	my @gids = ($gid);
	while (my (undef, undef, $id, $members) = getgrent()) {
		next if $id == $gid;
		push @gids, $id if any { $_ eq $user } split ' ', $members;
	}
	
	setgid($gid);
	return _error($app, qq{Can't switch to group "$group": $!}) if $!;
	setgroups(@gids);
	return _error($app, qq{Can't set supplemental GIDs "@gids": $!}) if $!;
	setuid($uid);
	return _error($app, qq{Can't switch to user "$user": $!}) if $!;
	
	return 1;
}

1;

=head1 NAME

Mojolicious::Plugin::SetUserGroup - Mojolicious plugin to set unprivileged
credentials

=head1 SYNOPSIS

  sub startup {
    my $self = shift;
    $self->plugin(SetUserGroup => {user => $user, group => $group});
  }

=head1 DESCRIPTION

This plugin is intended to replace the C<setuidgid> functionality of
L<Mojo::Server>. It should be loaded in application startup and it will change
the user and group credentials of the process when L<Mojo::IOLoop> is started,
which occurs in each worker process of a L<Mojo::Server::Prefork> daemon like
L<hypnotoad>.

This allows an application to be started as root so it can bind to privileged
ports such as port 80 or 443, but run worker processes as unprivileged users.
However, if the application is not started as root, it will most likely fail to
change privileges. So, you should only set the user/group when the application
is started as root.

To change privileges only when running under L<hypnotoad>, you can store the
user and group in hypnotoad configuration:

  $self->plugin(SetUserGroup => {user => $self->config->{hypnotoad}{user},
    group => $self->config->{hypnotoad}{group});

To change privileges only in production mode, conditionally register the plugin
in that mode:

  $self->plugin(SetUserGroup => {user => $user, group => $group}
    if $self->mode eq 'production';

This module requires L<Unix::Groups> and thus will only work on Unix-like
systems like Linux, OS X and BSD.

=head1 METHODS

L<Mojolicious::Plugin::SetUserGroup> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new, {user => $user, group => $group});

Install callback to change process privileges on the next L<Mojo::IOLoop> tick.
If option C<user> is undefined, no privilege change will occur. If option
C<group> is undefined but C<user> is defined, the group will be set to a group
matching the user name. If privilege changes fail, an error will be logged and
the process will be stopped.

=head1 AUTHOR

Dan Book, C<dbook@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2015, Dan Book.

This library is free software; you may redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 SEE ALSO

L<Mojolicious>, L<POSIX>, L<Unix::Groups>
