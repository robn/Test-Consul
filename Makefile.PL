# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.047.
use strict;
use warnings;



use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Run a consul server for testing",
  "AUTHOR" => "Robert Norris <rob\@eatenbyagrue.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Test-Consul",
  "LICENSE" => "perl",
  "NAME" => "Test::Consul",
  "PREREQ_PM" => {
    "Carp" => 0,
    "File::Temp" => 0,
    "File::Which" => 0,
    "HTTP::Tiny" => 0,
    "JSON::MaybeXS" => 0,
    "Net::EmptyPort" => 0,
    "POSIX" => 0,
    "Path::Tiny" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Test::Exception" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.004",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "File::Temp" => 0,
  "File::Which" => 0,
  "HTTP::Tiny" => 0,
  "JSON::MaybeXS" => 0,
  "Net::EmptyPort" => 0,
  "POSIX" => 0,
  "Path::Tiny" => 0,
  "Test::Exception" => 0,
  "Test::More" => 0,
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);