=head1 NAME

CLIPSeqTools::Role::Option::Verbosity - Role to enable verbosity as command line option

=head1 SYNOPSIS

Role to enable verbosity as command line option

  Defines options.
      -v --verbose         print progress lines and extra information.

=cut


package CLIPSeqTools::Role::Option::Verbosity;


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use Moose::Role;
use MooseX::App::Role;


#######################################################################
#######################   Command line options   ######################
#######################################################################
option 'verbose' => (
	is            => 'rw',
	isa           => 'Bool',
	cmd_aliases   => 'v',
	documentation => 'print progress lines and extra information.',
);


#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {}


1;
