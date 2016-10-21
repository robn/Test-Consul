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

# METHODS

## start

    my $tc = Test::Consul->start;

Starts a Consul instance. This method can take a moment to run, because it
waits until Consul's HTTP endpoint is available before returning. If it fails
for any reason an exception is thrown. In this way you can be sure that Consul
is ready for service if this method returns successfully.

The returned object is a guard. `end` is called when it goes out of scope, so
if you don't store it your Consul server will be killed before it even gets
started.

`start` takes the following arguments:

- `port`

    Port for the HTTP service. If not provided, an unused port between 49152 and 65535
    (inclusive) is chosen at random.

- `datadir`

    Directory for Consul's datastore. If not provided, the `-dev` option is used and
    no datadir is used.

- `bin`

    Location of the `consul` binary. If not provided, the `CONSUL_BIN` env variable
    will be used, and if that is not set then `$PATH` will be searched for it.

- `enable_acls`

    Set this to true to enable ACLs.

- `acl_default_policy`

    Set this to either `allow` or `deny`. The default is `allow`.
    See [https://www.consul.io/docs/agent/options.html#acl\_default\_policy](https://www.consul.io/docs/agent/options.html#acl_default_policy) for more
    information.

## end

Kill the Consul instance. Graceful shutdown is attempted first, and if it
doesn't die within a couple of seconds, the process is killed.

This method is also called if the guard object returned by `start` falls out
of scope.

## running

Returns a true value if the Consul instance is running, false otherwise.

## port

Returns the port that the Consul's HTTP server is listening on.

## bin

Returns the path to the `consul` binary that was used to start the instance.

## datadir

Returns the path to the data dir, if one was set.

## enable\_acls

Returns the `enable_acls` argument which was set when ["start"](#start) was called.

## acl\_default\_policy

Returns the `acl_default_policy` argument which was set when ["start"](#start) was
called.

## acl\_master\_token

Returns the master ACL token.

## skip\_all\_if\_no\_bin

    Test::Consul->skip_all_if_no_bin;

This class method issues a `skip_all` on the main package if the
consul binary could not be found.

# SEE ALSO

- [Consul](https://metacpan.org/pod/Consul) - Consul client library. Uses [Test::Consul](https://metacpan.org/pod/Test::Consul) in its test suite.

# SUPPORT

## Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at [https://github.com/robn/Consul-Test/issues](https://github.com/robn/Consul-Test/issues).
You will be notified automatically of any progress on your issue.

## Source Code

This is open source software. The code repository is available for
public review and contribution under the terms of the license.

[https://github.com/robn/Consul-Test](https://github.com/robn/Consul-Test)

    git clone https://github.com/robn/Consul-Test.git

# AUTHORS

- Robert Norris <rob@eatenbyagrue.org>

# CONTRIBUTORS

- Aran Deltac <bluefeet@gmail.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Robert Norris.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
