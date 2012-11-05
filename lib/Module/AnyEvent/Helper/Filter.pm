package Module::AnyEvent::Helper::Filter;

use strict;
use warnings;

# ABSTRACT: source filter for AnyEvent-ize helper
our $VERSION = 'v0.0.3'; # VERSION

use Carp;

BEGIN {
	require filtered;
}

sub import
{
	my ($pkg, %arg) = @_;
	my ($with);
	$arg{-remove_func} ||= [];
	$arg{-translate_func} ||= [];
	$arg{-replace_func} ||= [];
	$arg{-delete_func} ||= [];
	if(exists $arg{-transformer}) {
		my $transformer = 'Module::AnyEvent::Helper::PPI::Transform::' . $arg{-transformer};
		eval "require $transformer";
		croak "Can't load ${transformer}: $@" if $@;
		$with = <<EOF;
'PPI::Transform::Sequence',
$transformer => [],
Module::AnyEvent::Helper::PPI::Transform => [
-remove_func => [qw(@{$arg{-remove_func}})],
-translate_func => [qw(@{$arg{-translate_func}})],
-replace_func => [qw(@{$arg{-replace_func}})],
-delete_func => [qw(@{$arg{-delete_func}})]]
EOF
	} else {
		$with = <<EOF;
'Module::AnyEvent::Helper::PPI::Transform',
-remove_func => [qw(@{$arg{-remove_func}})],
-translate_func => [qw(@{$arg{-translate_func}})],
-replace_func => [qw(@{$arg{-replace_func}})],
-delete_func => [qw(@{$arg{-delete_func}})]
EOF
	}
	filtered->import(
		by => 'Filter::PPI::Transform',
		with => $with,
		on => $arg{-target},
		as => $arg{-as},
		use_ppi => 1,
		()
	);
}

1;

__END__

=pod

=head1 NAME

Module::AnyEvent::Helper::Filter - source filter for AnyEvent-ize helper

=head1 VERSION

version v0.0.3

=head1 SYNOPSIS

If Foo.pm is written as follows:

  package Foo;
  sub new { # constrcutor
  }
  sub impl { # blocking code
  }
  sub func { # calling impl()
      return 1 + impl(@_);
  }
  1;

FooAsync.pm, AnyEvent-friendly version of Foo.pm, can be implemented as the following:

  package FooAsync;
  use AnyEvent;
  sub impl_async { # non-blocking code
      my $cv = AE::cv;
      ...
      return $cv;
  }
  use Module::AnyEvent::Helper::Filter -as => FooAsync, -target => Foo,
       -remove_func => [qw(impl)], -translate_func => [qw(func)];
  1;

It is important to place C<use Module::AnyEvent::Helper::Filter> after method definitions
because methods are generated inside the C<use> according to prior method definitions.

=head1 DESCRIPTION

To make some modules AnyEvent-frinedly, it might be necessary to write boiler-plate codes and
to make many copy-paste-modify.
This module helps you to make use of source filter.
For the best case, you only need to convert central blocking code to non-blocking and others are generated by this filter.
For example, Foo.pm in SYNOPSIS is filtered, semantically, as the following:

  use AnyEvent;
  use Module::AnyEvent::Helper;
  package FooAsync;
  sub new { # constrcutor # keep as it is
  }
  # impl() is removed, and calling impl() is converted to calling impl_async()
  sub func_async { # func() is translated
      my $___cv___ = AE::cv;
      Module::AnyEvent::Helper::bind_scalar($___cv___, impl_async(@_), sub {
          return 1 + shift->recv;
      });
      return $___cv___;
  }
  Module::AnyEvent::Helper::strip_async_all();
  1;

See L<Module::AnyEvent::Helper::PPI::Transform> for actual conversion and L<Module::AnyEvent::Helper> for utility functions.

To combine with your implementation of impl_async(), package FooAsync can be used like:

  my $obj = FooAsync->new;
  $obj->func(1,2); # Blocking manner possible
  $obj->func_async(1,2)->cb(sub {}); # Non-blocking manner also possible

=head1 OPTIONS

=head2 C<-target>

Specify filter target module.

=head2 C<-as>

Specify name of filtered result module.

=head2 C<-remove_func>

Specify array reference of removing methods.
The function definition is removed and calling the function is converted to calling async version.
If you want to implement async version of the methods and to convert to ordinary version, you specify them in this option.

=head2 C<-translate_func>

Specify array reference of translating methods.
The function definition is converted to async version and calling the function is converted to calling async version.

=head2 C<-replace_func>

Specify array reference of replacing methods.
The function definition is kept as it is and calling the function is converted to calling async version.
It is expected that async version is implemented elsewhere.

=head2 C<-delete_func>

Specify array reference of deleting methods.
The function definition is removed and calling the function is kept as it is.
If you want to implement not-async version of the methods and do not want async version,
you specify them in this option.

=head2 C<-transformer>

Specify name of additional transformr module.
C<'Module::AnyEvent::Helper::PPI::Transform::'> is prepended to the name.
It should be a aubclass of L<PPI::Transform>.

=head1 SEE ALSO

This module is a tiny wrapper for the following modules.

=over 4

=item *

L<filtered> - Enable to apply source filter on external module

=item *

L<Filter::PPI::Transform> -  Tiny adapter from PPI::Transform to source filter

=item *

L<Module::AnyEvent::Helper::PPI::Transform> - Actual transformation is implemented here.

=back

=head1 AUTHOR

Yasutaka ATARASHI <yakex@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Yasutaka ATARASHI.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
