package Test::Consul;

# ABSTRACT: Run a consul server for testing

use warnings;
use strict;

use File::Which qw(which);
use JSON::MaybeXS qw(JSON encode_json);
use Path::Tiny;
use POSIX qw(WNOHANG);
use Carp qw(croak);
use HTTP::Tiny;
use Net::EmptyPort qw( check_port );
use File::Temp qw( tempfile );

sub start {
    my ($class, %args) = @_;

    my $bin = $args{bin} || $class->bin();
    unless ($bin && -x $bin) {
        croak "can't find consul binary";
    }

    my $port    = $args{port}    || _unique_empty_port();
    my $datadir = $args{datadir};

    # Make sure we have at least Consul 0.6.1 which supports the -dev option.
    my ($version) = qx{$bin version};
    if ($version and $version =~ m{v(\d+)\.(\d+)\.(\d+)}) {
        $version = sprintf('%03d%03d%03d', $1, $2, $3);
    }
    else {
        $version = 0;
    }

    unless ($version >= 6_001) {
        croak "consul not version 0.6.1 or newer";
    }

    my @opts;

    my %config = (
        node_name  => 'perl-test-consul',
        datacenter => 'perl-test-consul',
        bind_addr  => '127.0.0.1',
        ports => {
            dns      => -1,
            http     => $port,
            https    => -1,
            rpc      => _unique_empty_port(),
            serf_lan => _unique_empty_port(1),
            serf_wan => _unique_empty_port(1),
            server   => _unique_empty_port(),
        },
    );

    # Version 0.7.0 reduced default performance behaviors in a way
    # that makese these tests slower to startup.  Override this and
    # make leadership election happen ASAP.
    if ($version >= 7_000) {
        $config{performance} = { raft_multiplier => 1 };
    }

    my $enable_acls        = $args{enable_acls};
    my $acl_default_policy = $args{acl_default_policy} || 'allow';
    if ($enable_acls) {
        $config{acl_master_token} = $class->acl_master_token();
        $config{acl_default_policy} = $acl_default_policy;
        $config{acl_datacenter} = 'perl-test-consul';
        $config{acl_token} = $class->acl_master_token();
    }

    my $configpath;
    if (defined $datadir) {
        $config{data_dir}  = $datadir;
        $config{bootstrap} = JSON->true;
        $config{server}    = JSON->true;

        my $datapath = path($datadir);
        $datapath->remove_tree;
        $datapath->mkpath;

        $configpath = $datapath->child("consul.json");
    }
    else {
      push @opts, '-dev';
      $configpath = path( ( tempfile() )[1] );
    }

    $configpath->spew( encode_json(\%config) );
    push @opts, '-config-file', "$configpath";

    my $pid = fork();
    unless (defined $pid) {
        croak "fork failed: $!";
    }
    unless ($pid) {
        exec $bin, "agent", @opts;
    }

    my $http = HTTP::Tiny->new(timeout => 10);
    my $now = time;
    my $res;
    while (time < $now+30) {
        $res = $http->get("http://127.0.0.1:$port/v1/status/leader");
        last if $res->{success} && $res->{content} =~ m/^"[0-9\.]+:[0-9]+"$/;
        sleep 1;
    }
    unless ($res->{success}) {
        kill 'KILL', $pid;
        croak "consul API test failed: $res->{status} $res->{reason}";
    }

    unlink $configpath if !defined $datadir;

    my $self = {
        bin     => $bin,
        port    => $port,
        datadir => $datadir,
        _pid    => $pid,
        enable_acls        => $enable_acls,
        acl_default_policy => $acl_default_policy,
    };

    return bless $self, $class;
}

my $start_port = 49152;
my $current_port = $start_port;
my $end_port  = 65535;

sub _unique_empty_port {
    my ($udp_too) = @_;

    my $port = 0;
    while ($port == 0) {
      $current_port ++;
      $current_port = $start_port if $current_port > $end_port;
      next if check_port( undef, $current_port, 'tcp' );
      next if $udp_too and check_port( undef, $current_port, 'udp' );
      $port = $current_port;
    }

    return $port;
}

sub skip_all_if_no_bin {
  my ($self) = @_;

  croak 'The skip_all_if_no_bin method may only be used if the plan ' .
        'function is callable on the main package (which Test::More ' .
        'and Test2::Tools::Basic provide)'
        if !main->can('plan');

  return if $self->bin();

  main::plan( skip_all => 'The Consul binary must be available to run this test.' );
}

sub end {
    my ($self) = @_;
    return unless $self->{_pid};
    my $pid = delete $self->{_pid};
    kill 'TERM', $pid;
    my $now = time;
    while (time < $now+2) {
        return if waitpid($pid, WNOHANG) > 0;
    }
    kill 'KILL', $pid;
}

sub DESTROY {
    goto \&end;
}

sub running { !!shift->{_pid} }

sub port    { shift->{port} }
sub datadir { shift->{datadir} }

sub enable_acls        { shift->{enable_acls} }
sub acl_default_policy { shift->{acl_default_policy} }
sub acl_master_token   { '01234567-89AB-CDEF-GHIJ-KLMNOPQRSTUV' }

my ($bin, $bin_searched_for);
sub bin {
  my ($self) = @_;
  return $self->{bin} if ref $self;
  return $bin if $bin_searched_for;
  $bin = $ENV{CONSUL_BIN} || which "consul";
  $bin_searched_for = 1;
  return $bin;
}

1;

=pod

=encoding UTF-8

=for markdown [![Build Status](https://secure.travis-ci.org/robn/Test-Consul.png)](http://travis-ci.org/robn/Test-Consul)

=head1 NAME

Test::Consul - Run a Consul server for testing

=head1 SYNOPSIS

    use Test::Consul;
    
    # succeeds or dies
    my $tc = Test::Consul->start;
    
    my $consul_baseurl = "http://127.0.0.1:".$tc->port;
    
    # do things with Consul here
    
    # kill test server (or let $tc fall out of scope, destructor will clean up)
    $tc->end;

=head1 DESCRIPTION

This module starts and stops a standalone Consul instance. It's designed to be
used to help test Consul-aware Perl programs.

It's assumed that you have Consul 0.6.4 installed somewhere.

=head1 METHODS

=head2 start

    my $tc = Test::Consul->start;

Starts a Consul instance. This method can take a moment to run, because it
waits until Consul's HTTP endpoint is available before returning. If it fails
for any reason an exception is thrown. In this way you can be sure that Consul
is ready for service if this method returns successfully.

The returned object is a guard. C<end> is called when it goes out of scope, so
if you don't store it your Consul server will be killed before it even gets
started.

C<start> takes the following arguments:

=over 4

=item *

C<port>

Port for the HTTP service. If not provided, an unused port between 49152 and 65535
(inclusive) is chosen at random.

=item *

C<datadir>

Directory for Consul's datastore. If not provided, the C<-dev> option is used and
no datadir is used.

=item *

C<bin>

Location of the C<consul> binary. If not provided, the C<CONSUL_BIN> env variable
will be used, and if that is not set then C<$PATH> will be searched for it.

=item *

C<enable_acls>

Set this to true to enable ACLs.

=item *

C<acl_default_policy>

Set this to either C<allow> or C<deny>. The default is C<allow>.
See L<https://www.consul.io/docs/agent/options.html#acl_default_policy> for more
information.

=back

=head2 end

Kill the Consul instance. Graceful shutdown is attempted first, and if it
doesn't die within a couple of seconds, the process is killed.

This method is also called if the guard object returned by C<start> falls out
of scope.

=head2 running

Returns a true value if the Consul instance is running, false otherwise.

=head2 port

Returns the port that the Consul's HTTP server is listening on.

=head2 bin

Returns the path to the C<consul> binary that was used to start the instance.

=head2 datadir

Returns the path to the data dir, if one was set.

=head2 enable_acls

Returns the C<enable_acls> argument which was set when L</start> was called.

=head2 acl_default_policy

Returns the C<acl_default_policy> argument which was set when L</start> was
called.

=head2 acl_master_token

Returns the master ACL token.

=head2 skip_all_if_no_bin

    Test::Consul->skip_all_if_no_bin;

This class method issues a C<skip_all> on the main package if the
consul binary could not be found.

=head1 SEE ALSO

=over 4

=item *

L<Consul> - Consul client library. Uses L<Test::Consul> in its test suite.

=back

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/robn/Consul-Test/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software. The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/robn/Consul-Test>

  git clone https://github.com/robn/Consul-Test.git

=head1 AUTHORS

=over 4

=item *

Robert Norris <rob@eatenbyagrue.org>

=back

=head1 CONTRIBUTORS

=over 4

=item *

Aran Deltac <bluefeet@gmail.com>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Robert Norris.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
