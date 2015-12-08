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

sub start {
    my ($class, %args) = @_;

    my $bin = $args{bin} || which "consul";
    unless ($bin && -x $bin) {
        croak "can't find consul binary";
    }

    my $port    = $args{port}    || int(rand(100))+28500;
    my $datadir = $args{datadir} || '/tmp/perl-test-consul';

    my ($version) = qx{$bin version};
    unless ($version && $version =~ m/Consul v0.6.0/) {
        croak "consul not version 0.6.0";
    }

    my $config = encode_json({
        data_dir       => $datadir,
        node_name      => 'perl-test-consul',
        datacenter     => 'perl-test-consul',
        bootstrap      => JSON->true,
        server         => JSON->true,
        advertise_addr => '127.0.0.1',
        ports => {
            dns   => -1,
            http  => $port,
            https => -1,
        },
    });

    my $datapath = path($datadir);
    $datapath->remove_tree;
    $datapath->mkpath;
    my $configpath = $datapath->child("consul.json");
    $configpath->spew($config);

    my $pid = fork();
    unless (defined $pid) {
        croak "fork failed: $!";
    }
    unless ($pid) {
        exec $bin, "agent", "-config-file=$configpath";
    }

    my $http = HTTP::Tiny->new(timeout => 10);
    my $now = time;
    my $res;
    while (time < $now+5) {
        $res = $http->get("http://127.0.0.1:$port/v1/status/leader");
        last if $res->{success} && $res->{content} =~ m/^"[0-9\.]+:[0-9]+"$/;
        sleep 1;
    }
    unless ($res->{success}) {
        kill 'KILL', $pid;
        croak "consul API test failed: $res->{status} $res->{reason}";
    }

    my $self = {
        bin     => $bin,
        port    => $port,
        datadir => $datadir,
        _pid    => $pid,
    };

    return bless $self, $class;
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
sub bin     { shift->{bin} }
sub datadir { shift->{datadir} }

1;

=pod

=encoding UTF-8

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

It's assumed that you have Consul 0.6.0 installed somewhere.

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

Port for the HTTP service. If not provided, a port between 28500 and 28599
(inclusive) is chosen at random.

=item *

C<datadir>

Directory for Consul's datastore. If not provided, defaults to
C</tmp/perl-test-consul>.

=item *

C<bin>

Location of the C<consul> binary. If not provided, C<$PATH> will be searched
for it.

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

Returns the path to the data dir.

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

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Robert Norris.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
