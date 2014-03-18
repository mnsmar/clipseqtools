# POD documentation - main docs before the code

=head1 NAME

CLIPSeqTools::PlotApp - A collection of tools to create plots for the output of CLIPSeqTools.

=head1 SYNOPSIS

CLIPSeqTools::PlotApp provides tools to create plots for the output of CLIPSeqTools.

=head1 DESCRIPTION

CLIPSeqTools::PlotApp is primarily a collection of scripts and modules that can be used to create plots for the output of CLIPSeqTools.

=head1 EXAMPLES

=cut


package CLIPSeqTools::PlotApp;


# Make it an App and load plugins
use MooseX::App qw(Config Color BashCompletion Man);
extends 'CLIPSeqTools::App';


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;


1;
