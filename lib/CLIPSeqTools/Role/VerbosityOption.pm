=head1 NAME

CLIPSeqTools::Role::VerbosityOption - Role to enable verbose option from the command line

=head1 SYNOPSIS

Role to enable verbosity option from the command line

  Defines options.
      -v --verbose         print progress lines and extra information.

=cut


package CLIPSeqTools::Role::VerbosityOption;


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
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
