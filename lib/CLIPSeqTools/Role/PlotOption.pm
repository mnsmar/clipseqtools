=head1 NAME

CLIPSeqTools::Role::PlotOption - Role to enable plot option from the command line

=head1 SYNOPSIS

Role to enable plot option from the command line

  Defines options.
      --plot            call plotting script to create plots.

=cut


package CLIPSeqTools::Role::PlotOption;


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use Moose::Role;
use MooseX::App::Role;


#######################################################################
####################   Load CLIPSeqTools plotting   ###################
#######################################################################
use CLIPSeqTools::PlotApp;


#######################################################################
#######################   Command line options   ######################
#######################################################################
option 'plot' => (
	is            => 'rw',
	isa           => 'Bool',
	documentation => 'call plotting script to create plots.',
);


#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {}


1;
