[![Build Status](https://secure.travis-ci.org/robn/Test-Consul.png)](http://travis-ci.org/robn/Test-Consul)

# NAME

Test::Consul - Run a Consul server for testing

# SYNOPSIS

    use Test::Consul;
    
    # succeeds or dies
    my $tc = Test::Consul->start;
    
    my $consul_baseurl = "http://127.0.0.1:".$tc->port;
    
    # do things with Consul here
    
    # kill test server (or let $tc fall out of scope, destructor will clean up)
    $tc->end;

# DESCRIPTION

This module starts and stops a standalone Consul instance. It's designed to be
used to help test Consul-aware Perl programs.

It's assumed that you have Consul 0.6.4 installed somewhere.

# ARGUMENTS

## port

The TCP port for HTTP API endpoint.  Consul's default is `8500`, but
this defaults to a random unused port.

## serf\_lan\_port

The TCP and UDP port for the Serf LAN.  Consul's default is `8301`, but
this defaults to a random unused port.

## serf\_wan\_port

The TCP and UDP port for the Serf WAN.  Consul's default is `8302`, but
this defaults to a random unused port.

## server\_port

The TCP port for the RPC Server address.  Consul's default is `8300`, but
this defaults to a random unused port.

## node\_name

The name of this node. If not provided, one will be generated.

## datacenter

The name of the datacenter. If not provided, one will be generated.

## enable\_acls

Set this to true to enable ACLs. Note that Consul ACLs changed substantially in
Consul 1.4, and [Test::Consul](https://metacpan.org/pod/Test%3A%3AConsul) has not yet been updated to support them. If
you try to enable them with Consul 1.4+, [Test::Consul](https://metacpan.org/pod/Test%3A%3AConsul) will croak. See
[https://github.com/robn/Test-Consul/issues/7](https://github.com/robn/Test-Consul/issues/7) for more info.

## acl\_default\_policy

Set this to either `allow` or `deny`. The default is `allow`.
See [https://www.consul.io/docs/agent/options.html#acl\_default\_policy](https://www.consul.io/docs/agent/options.html#acl_default_policy) for more
information.

## acl\_master\_token

If ["enable\_acls"](#enable_acls) is true then this token will be used as the master
token.  By default this will be `01234567-89AB-CDEF-GHIJ-KLMNOPQRSTUV`.

## enable\_acls

Set this to true to enable remote execution (off by default since Consul 0.8.0)

## bin

Location of the `consul` binary.  If not provided then the binary will
be retrieved from ["found\_bin"](#found_bin).

## datadir

Directory for Consul's data store. If not provided, the `-dev` option is used
and no datadir is used.

# ATTRIBUTES

## running

Returns `true` if ["start"](#start) has been called and ["stop"](#stop) has not been called.

# METHODS

## start

    # As an object method:
    my $tc = Test::Consul->new(%args);
    $tc->start();
    
    # As a class method:
    my $tc = Test::Consul->start(%args);

Starts a Consul instance. This method can take a moment to run, because it
waits until Consul's HTTP endpoint is available before returning. If it fails
for any reason an exception is thrown. In this way you can be sure that Consul
is ready for service if this method returns successfully.

## stop

    $tc->stop();

Kill the Consul instance. Graceful shutdown is attempted first, and if it
doesn't die within a couple of seconds, the process is killed.

This method is also called if the instance of this class falls out of scope.

## join

    my $tc1 = Test::Consul->start;
    my $tc2 = Test::Consul->start(datacenter => $tc1);
    $tc1->wan_join($tc2);

Perform a join to another [Test::Consul](https://metacpan.org/pod/Test%3A%3AConsul) instance. Use this to test Consul applications that operate across nodes.

## wan\_join

    my $tc1 = Test::Consul->start;
    my $tc2 = Test::Consul->start;
    $tc1->wan_join($tc2);

Perform a WAN join to another [Test::Consul](https://metacpan.org/pod/Test%3A%3AConsul) instance. Use this to test Consul
applications that operate across datacenters.

# CLASS METHODS

See also ["start"](#start) which acts as both a class and instance method.

## found\_bin

Return the value of the `CONSUL_BIN` env var, if set, or uses [File::Which](https://metacpan.org/pod/File%3A%3AWhich)
to search the system for an installed binary.  Returns `undef` if no consul
binary could be found.

## skip\_all\_if\_no\_bin

    Test::Consul->skip_all_if_no_bin;

This class method issues a `skip_all` on the main package if the
consul binary could not be found (["found\_bin"](#found_bin) returns false).

## found\_version

Return the version of the consul binary, by running the binary return by
["found\_bin"](#found_bin) with the `version` argument. Returns 0 if the version can't be
determined.

## skip\_all\_unless\_version

    Test::Consul->skip_all_unless_version($minver, [$maxver]);

This class method issues a `skip_all` on the main package if the consul binary
is not between `$minver` and `$maxvar` (exclusive).

# SEE ALSO

- [Consul](https://metacpan.org/pod/Consul) - Consul client library. Uses [Test::Consul](https://metacpan.org/pod/Test%3A%3AConsul) in its test suite.

# SUPPORT

## Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at [https://github.com/robn/Test-Consul/issues](https://github.com/robn/Test-Consul/issues).
You will be notified automatically of any progress on your issue.

## Source Code

This is open source software. The code repository is available for
public review and contribution under the terms of the license.

[https://github.com/robn/Test-Consul](https://github.com/robn/Test-Consul)

    git clone https://github.com/robn/Test-Consul.git

# AUTHORS

- Rob N ★ <robn@robn.io>

# CONTRIBUTORS

- Aran Deltac <bluefeet@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Rob N ★ and was supported by FastMail
Pty Ltd.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
