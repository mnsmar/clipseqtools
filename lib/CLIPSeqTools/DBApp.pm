# POD documentation - main docs before the code

=head1 NAME

CLIPSeqTools::DBApp - A collection of tools for managing database tables for CLIPSeqTools.

=head1 SYNOPSIS

CLIPSeqTools::DBApp provides tools for management of databases that are compatible with CLIPSeqTools.

=head1 DESCRIPTION

CLIPSeqTools::DBApp is primarily a collection of scripts and modules that can be used for management of databases that are compatible with CLIPSeqTools.
It provides functionality for converting SAM files to database tables and annotating this tables with extra infromation such as transcripts, 3'UTRs, repeats etc.

=head1 EXAMPLES

=cut


package CLIPSeqTools::DBApp;


# Make it an App and load plugins
use MooseX::App qw(Config Color BashCompletion Man);
extends 'CLIPSeqTools::App';


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;


1;
