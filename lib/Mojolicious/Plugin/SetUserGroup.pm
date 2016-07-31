package Mojolicious::Plugin::SetUserGroup;
use Mojo::Base 'Mojolicious::Plugin';

use List::Util 'any';
use Mojo::IOLoop;
use POSIX qw(geteuid getegid setuid setgid);
use Unix::Groups 'setgroups';
use Carp 'croak';

our $VERSION = '0.005';

sub register {
	my ($self, $app, $conf) = @_;
	my $user = $conf->{user};
	my $group = $conf->{group} // $user;
	
	return $self unless defined $user;
	
	# Make sure desired user and group exist
	$! = 0;
	unless (defined(getpwnam $user)) {
		croak _error($app, qq{Failed to retrieve user "$user": $!}) if $!;
		croak _error($app, qq{User "$user" does not exist});
	}
	$! = 0;
	unless (defined(getgrnam $group)) {
		croak _error($app, qq{Failed to retrieve group "$group": $!}) if $!;
		croak _error($app, qq{Group "$group" does not exist});
	}
	
	Mojo::IOLoop->next_tick(sub { _setusergroup($app, $user, $group) });
}

sub _error {
	my ($app, $error) = @_;
	chomp $error;
	$app->log->fatal($error);
	Mojo::IOLoop->stop if Mojo::IOLoop->is_running;
	return $error;
}

sub _setusergroup {
	my ($app, $user, $group) = @_;
	
	# User and group IDs
	my ($uid, $gid);
	$! = 0;
	unless (defined($uid = getpwnam $user)) {
		return _error($app, qq{Failed to retrieve user "$user": $!}) if $!;
		return _error($app, qq{User "$user" does not exist});
	}
	$! = 0;
	unless (defined($gid = getgrnam $group)) {
		return _error($app, qq{Failed to retrieve group "$group": $!}) if $!;
		return _error($app, qq{Group "$group" does not exist});
	}
	
	# Check if user and group are already correct
	return undef if geteuid() == $uid and getegid() == $gid;
	
	# Secondary groups
	my @gids = ($gid);
	my @groups = ($group);
	$! = 0;
	while (my ($name, undef, $id, $members) = getgrent) {
		if ($id != $gid and any { $_ eq $user } split ' ', $members) {
			push @gids, $id;
			push @groups, $name;
		}
	} continue { $! = 0; }
	# Empty list may indicate getgrent is done, or an error
	return _error($app, qq{Failed to read groups: $!}) if $!;
	
	unless (setgid($gid) == 0) { return _error($app, qq{Can't switch to group "$group": $!}); }
	unless (setgroups(@gids)) { return _error($app, qq{Can't set supplemental groups "@groups": $!}); }
	unless (setuid($uid) == 0) { return _error($app, qq{Can't switch to user "$user": $!}); }
}

1;

=head1 NAME

Mojolicious::Plugin::SetUserGroup - Mojolicious plugin to set unprivileged
credentials

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin(SetUserGroup => {user => $user, group => $group});
  
  # Mojolicious::Lite
  plugin SetUserGroup => {user => $user, group => $group};
  
  # Production mode only
  plugin SetUserGroup => {user => $user, group => $group}
    if $self->mode eq 'production';
  
  # Root only
  plugin SetUserGroup => {user => $user, group => $group}
    if $< == 0 or $> == 0;

=head1 DESCRIPTION

This plugin is intended to replace the C<setuidgid> functionality of
L<Mojo::Server>. It should be loaded in application startup and it will change
the user and group credentials of the process when L<Mojo::IOLoop> is started,
which occurs in each worker process of a L<Mojo::Server::Prefork> daemon like
L<hypnotoad>.

This allows an application to be started as root so it can bind to privileged
ports such as port 80 or 443, but run worker processes as unprivileged users.
However, if the application is not started as root, it will most likely fail to
change credentials. So, you should only set the user/group when the application
is started as root.

This module requires L<Unix::Groups> and thus will only work on Unix-like
systems like Linux, OS X, and BSD.

=head1 METHODS

L<Mojolicious::Plugin::SetUserGroup> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new, {user => $user, group => $group});

Install callback to change process credentials on the next L<Mojo::IOLoop>
tick. If option C<user> is undefined or the current effective user and group
are already correct, no credential change will occur. If option C<group> is
undefined but C<user> is defined, the group will be set to a group matching the
user name. If credential changes fail, an error will be logged and the process
will be stopped.

=head1 AUTHOR

Dan Book, C<dbook@cpan.org>

=head1 CONTRIBUTORS

=over

=item Jan Henning Thorsen (jhthorsen)

=item Lee Johnson (leejo)

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2015, Dan Book.

This library is free software; you may redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 SEE ALSO

L<Mojolicious>, L<POSIX>, L<Unix::Groups>
