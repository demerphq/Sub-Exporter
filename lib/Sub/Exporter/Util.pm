use strict;
use warnings;

package Sub::Exporter::Util;

our $VERSION = '0.01';

=head2 curry_class

  exports => {
    some_method => curry_class,
  }

This utility returns a generator which will produce a class-curried version of
a method.  In other words, it will export a method call with the exporting
class built in as the invocant.

A module importing the code some the above example might do this:

  use Some::Module qw(some_method);

  my $x = some_method;

This would be equivalent to:

  use Some::Module;

  my $x = Some::Module->some_method;

If Some::Module is subclassed and the subclass's import method is called to
import C<some_method>, the subclass will be curried in as the invocant.

=cut

sub curry_class {
  sub {
    my ($class, $name) = @_;
    sub { $class->$name(@_); };
  }
}

=head2 merge_col

  exports => {
    twiddle => merge_col(defaults => \&_twiddle_gen),
    tweak   => merge_col(defaults => \&_tweak_gen  ),
  }

This utility wraps the given generator in one that will merge the named
collection into its args before calling it.  This means that you can support a
"default" collector in multipe exports without writing the code each time.

=cut

sub merge_col {
  my ($default_name, $gen) = @_;
  sub {
    my ($class, $name, $arg, $col) = @_;

    my $merged_arg = exists $col->{$default_name}
                   ? { %{ $col->{$default_name} }, %$arg }
                   : $arg;

    $gen->($class, $name, $merged_arg, $col);
  }
}

=head2 mixin_exporter

This utility returns an exporter that will export into a superclass and adjust
the ISA importing class to include the newly generated superclass.

=cut

sub mixin_exporter {
  my ($mixin_class, $col_ref);
  sub {
    my ($class, $generator, $name, $arg, $collection, $as, $into) = @_;

    unless ($mixin_class and ($collection == $col_ref)) {
      require Package::Generator; # XXX remove this before release?
      $mixin_class = Package::Generator->new_package({
        base => "$class\:\:__mixin__",
      });
      $col_ref = 0 + $collection;
      no strict 'refs';
      unshift @{"$into" . "::ISA"}, $mixin_class;
    }
    $into = $mixin_class;
    Sub::Exporter::default_exporter($class, $generator, $name, $arg, $collection, $as, $into);
  };
}

1;