#!perl -T
use strict;
use warnings;

=head1 TEST PURPOSE

These tests check export group expansion, specifically the expansion of groups
that use group generators.

=cut

# XXX: The framework is stolen from expand-group.  I guess it should be
# factored out.  Whatever. -- rjbs, 2006-03-12

use Test::More 'no_plan';

BEGIN { use_ok('Sub::Exporter'); }

my $import_target;

my $alfa  = sub { 'alfa'  };
my $bravo = sub { 'bravo' };

my $returner = sub {
  my ($class, $group, $arg, $collection) = @_;

  my %given = (
    class => $class,
    group => $group,
    arg   => $arg,
    collection => $collection,
  );

  return {
    foo => sub { return { name => 'foo', %given }; },
    bar => sub { return { name => 'bar', %given }; },
  };
};

my $config = {
  exports => [ ],
  groups  => {
    alphabet  => sub { { a => $alfa, b => $bravo } },
    generated => $returner,
  },
  collectors => [ 'col1' ],
};

my @single_tests = (
  # [ comment, \@group, \@output ]
  # [ "simple group 1", [ ':A' => undef ] => [ [ a => undef ] ] ],
  [
    "simple group generator",
    [ -alphabet => undef ],
    [ [ a => $alfa ], [ b => $bravo ] ],
  ],
  [
    "simple group generator with prefix",
    [ -alphabet => { -prefix => 'prefix_' } ],
    [ [ prefix_a => $alfa ], [ prefix_b => $bravo ] ],
  ],
);

for my $test (@single_tests) {
  my ($label, $given, $expected) = @$test;
  
  my @got = Sub::Exporter::_expand_group(
    'Class',
    $config,
    $given,
    {},
  );

  is_deeply(\@got, $expected, "expand_group: $label");
}

for my $test (@single_tests) {
  my ($label, $given, $expected) = @$test;
  
  my $got = Sub::Exporter::_expand_groups(
    'Class',
    $config,
    [ $given ],
  );

  is_deeply($got, $expected, "expand_groups: $label [single test]");
}

my @multi_tests = (
  # [ $comment, \@groups, \@output ]
);

for my $test (@multi_tests) {
  my ($label, $given, $expected) = @$test;
  
  my $got = Sub::Exporter::_expand_groups(
    'Class',
    $config,
    $given,
  );

  is_deeply($got, $expected, "expand_groups: $label");
}

{
  my $got = Sub::Exporter::_expand_groups(
    'Class',
    $config,
    [ [ -alphabet => undef ] ],
    {},
  );

  my %code = map { $_->[0] => $_->[1] } @$got;

  my $a = $code{a};
  my $b = $code{b};

  is($a->(), 'alfa',  "generated 'a' sub does what we think");
  is($b->(), 'bravo', "generated 'b' sub does what we think");
}

{
  my $got = Sub::Exporter::_expand_groups(
    'Class',
    $config,
    [ [ -generated => { xyz => 1 } ] ],
    {},
    {},
    { col1 => { value => 2 } },
  );

  my %code = map { $_->[0] => $_->[1] } @$got;

  for (qw(foo bar)) {
    is_deeply(
      $code{$_}->(),
      {
        name  => $_,
        class => 'Class',
        group => 'generated',
        arg   => { xyz => 1 }, 
        collection => { col1 => { value => 2 } },
      },
      "generated foo does what we expect",
    );
  }
}