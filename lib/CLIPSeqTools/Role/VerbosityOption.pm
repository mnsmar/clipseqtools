=head1 NAME

CLIPSeqTools::Role::VerbosityOption - Role to enable verbose option from the command line

=head1 SYNOPSIS

Role to enable help option from the command line

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


#######################################################################
#######################   Command line options   ######################
#######################################################################
has 'verbose' => (
	is            => 'rw',
	isa           => 'Bool',
	traits        => ['Getopt'],
	cmd_aliases   => 'v',
	documentation => 'print progress lines and extra information.',
);


#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {}


1;
