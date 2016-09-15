package Test::Consul;

=head1 NAME

Test::Consul - Spawn an in-process Consul agent for testing.

=head1 SYNOPSIS

    use Test::Consul;
    
    my $consul = Test::Consul->new();
    $consul->start();
    
    my $url = $consul->api_v1_url() . '/agent/self';
    my $port = $consul->http_port();

=head1 DESCRIPTION

This module provides a very simple and easy way to launch a per-test Consul agent.
This agent is configured to run in dev mode, meaning it writes nothing to disk, and
all the ports it uses are set to available random ports.

It is expected that the consul binary will be available and in the C<PATH> env, or
otherwise executable from your shell as simply C<consul>.  If you have the Consul
binary installed somewhere else you can set the L</binary> argument (which also
supports being set by an env var).

When using this for tests you may find that following this workflow will be the most
useful:

    use Test::More;
    my $consul = Test::Consul->new();
    $consul->skip_all_if_binary_unavailable();
    $consul->start();
    # do your testing...

See more about this at L</skip_all_if_binary_unavailable>.

=cut

use Test::More qw();
use Daemon::Daemonize qw( daemonize check_pidfile write_pidfile does_process_exist );
use Net::EmptyPort qw( empty_port wait_port check_port );
use IPC::Cmd qw();
use Capture::Tiny qw( capture );
use Carp qw( croak );
use Time::HiRes qw();
use POSIX qw( :sys_wait_h );
use JSON::MaybeXS qw( encode_json );
use File::Temp qw( tempfile );

use Moo;
use strictures 2;
use namespace::clean;

sub DEMOLISH {
    my ($self) = @_;
    $self->_destructor->();
}

has _build_pid => (
    is       => 'ro',
    init_arg => undef,
    default  => sub{ $$ },
);

has _consul_pid => (
    is       => 'rw',
    init_arg => undef,
);

# I tend to not trust destructors and make sure I write ones which
# have no dependencies on any references.  I expect this isn't
# strictly necessary with this module, but I'm being paranoid in this
# case.
has _destructor => (
    is       => 'lazy',
    init_arg => undef,
    clearer => '_rebuild_desctructor',
    builder  => sub{
        my ($self) = @_;

        my $consul_pid   = $self->_consul_pid();
        my $build_pid    = $self->_build_pid();
        my $stop_timeout = $self->stop_timeout();

        $self = undef;

        return( sub{} ) if !$consul_pid;

        return sub{
            return if $$ != $build_pid;
            return if !does_process_exist( $consul_pid );

            kill 'INT', $consul_pid;

            my $overtime = time() + $stop_timeout;
            while (waitpid($consul_pid, WNOHANG) == 0) {
                last if time() > $overtime;
                Time::HiRes::sleep( 0.1 );
            }

            croak "Timeout exceeded waiting for Consul agent with pid $consul_pid to stop"
                if does_process_exist( $consul_pid );
        };
    },
);

after _rebuild_desctructor => sub{
    my ($self) = @_;
    $self->_destructor();
};

sub _generate_args {
    my ($self) = @_;

    return [
        '-dev',
        '-bootstrap-expect' => 1,
        '-bind' => '127.0.0.1',
    ];
}

sub _generate_config {
    my ($self) = @_;

    return {
        ports => {
            dns      => empty_port(),
            http     => empty_port(),
            rpc      => empty_port(),
            serf_lan => empty_port(),
            serf_wan => empty_port(),
            server   => empty_port(),
        },
    };
}

has _config => (
    is       => 'rw',
    init_arg => undef,
);

=head1 ARGUMENTS

=head2 start_timeout

How long to wait for the agent to start when L</start> is called.  Defaults
to C<5> (seconds) which is well more than sufficient.

=cut

has start_timeout => (
    is      => 'ro',
    default => 5,
);

=head2 stop_timeout

How long to wait for the agent to stop when L</stop> is called.  Defaults
to C<5> (seconds) which is well more than sufficient.

=cut

has stop_timeout => (
    is      => 'ro',
    default => 5,
);

=head2 binary

The name of the consul binary, including its path if appropriate.
Defaults to just C<consul>.

The C<CONSUL_BINARY> env var may be used to change the default.

=cut

has binary => (
    is => 'lazy',
);
sub _build_binary {
    my ($self) = @_;
    my $binary = $ENV{CONSUL_BINARY};
    $binary = 'consul' unless defined($binary) and $binary ne '';
    return $binary;
}

=head1 ATTRIBUTES

=head2 http_port

The port Consul is listening to HTTP requests on.  If Consul is not running
then this will throw an exception.

=cut

sub http_port {
    my ($self) = @_;
    croak 'The http_port is not available when the Consul agent is stopped' if !$self->is_running();
    return $self->_config->{ports}->{http};
}

=head2 http_url

Returns the full URL to Consul's HTTP interface.  Throws an exception if
Consul is not running.

=cut

sub http_url {
    my ($self) = @_;
    croak 'Cannot generate the http URL unless Consul is running' if !$self->is_running();
    return 'http://127.0.0.1:' . $self->_config->{ports}->{http};
}

=head2 api_v1_url

Returns the full URL to Consul's API v1 HTTP interface.  Throws an exception if
Consul is not running.

=cut

sub api_v1_url {
    my ($self) = @_;
    return $self->http_url() . '/v1';
}

=head2 is_binary_available

Returns true if the L</binary> is callable.

=cut

sub is_binary_available {
    my ($self) = @_;

    my ($success, $error, $full, $stdout, $stderr) = IPC::Cmd::run(
        command => [$self->binary(), 'version'],
    );

    return( $success ? 1 : 0 );
}

=head1 METHODS

=head2 skip_all_if_binary_unavailable

Calls L<Test::More>'s C<skip_all> if L</is_binary_available> returns false.

=cut

sub skip_all_if_binary_unavailable {
    my ($self) = @_;

    return if $self->is_binary_available();

    my $binary = $self->binary();
    Test::More::plan skip_all => "The Consul binary, $binary, must be installed to run this test.";
}

=head2 start

Starts the Consul agent and returns once its L</http_port> starts listening.

=cut

sub start {
    my ($self) = @_;

    croak "Cannot start, Consul is already running"
        if $self->is_running();

    croak 'Cannot start, the Consul binary is unavailable'
        if !$self->is_binary_available();

    my $args = $self->_generate_args();
    my $config = $self->_generate_config();

    my ($config_fh, $config_file) = tempfile();
    print $config_fh encode_json( $config );
    close $config_fh;
    push @$args, '-config-file' => $config_file;

    my $pid = fork();

    if (!$pid) {
        capture {
            exec(
                $self->binary(),
                'agent',
                @$args,
            );
        };
    }

    my $port = $config->{ports}->{http};
    wait_port( $port, $self->start_timeout() );

    unlink $config_file;

    croak "Timeout exceeded waiting for Consul agent with pid $pid to start listening on port $port"
        if !check_port( $port );

    $self->_consul_pid( $pid );
    $self->_config( $config );
    $self->_rebuild_desctructor();
    return;
}

=head2 stop

Stops the Consul agent.  Note that this isn't necessary to call in normal circumstances
the agent will be automatically stop when the object goes out of scope or the process exits.

=cut

sub stop {
    my ($self) = @_;

    croak "Cannot stop, Consul is not running"
        if !$self->is_running();

    my $pid = $self->_consul_pid();
    kill 'INT', $pid;

    my $overtime = time() + $self->stop_timeout();
    while (waitpid($pid, WNOHANG) == 0) {
        last if time() > $overtime;
        Time::HiRes::sleep( 0.1 );
    }

    croak "Timeout exceeded waiting for Consul agent with pid $pid to stop"
        if $self->is_running();

    $self->_consul_pid( undef );
    $self->_config( undef );
    return;
}

=head2 is_running

Returns true if L</start> has been called and the agent process is still running.

=cut

sub is_running {
    my ($self) = @_;

    my $pid = $self->_consul_pid();
    return 0 if !$pid;

    return( does_process_exist($pid) ? 1 : 0 );
}

1;
__END__

=head1 AUTHOR

Aran Clary Deltac <bluefeetE<64>gmail.com>

=head1 ACKNOWLEDGEMENTS

Thanks to L<ZipRecruiter|https://www.ziprecruiter.com/>
for encouraging their employees to contribute back to the open
source ecosystem.  Without their dedication to quality software
development this distribution would not exist.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

