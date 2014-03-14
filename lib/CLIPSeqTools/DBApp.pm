# POD documentation - main docs before the code

=head1 NAME

CLIPSeqTools::DBApp - A collection of tools for managing database tables for CLIPSeqTools.

=head1 SYNOPSIS

CLIPSeqTools::DBApp provides tools for database management of databases that are compatible with CLIPSeqTools.

=head1 DESCRIPTION

CLIPSeqTools::DBApp is primarily a collection of scripts and modules that can be used for database management of databases that are compatible with CLIPSeqTools.
It provides functionality for converting SAM files to database tables and annotating this tables with extra infromation such as genomic information.

Source code: The source has been deposited in GitHub L<https://github.com/palexiou/GenOO-CLIP>.
Contribute:  Please fork the GitHub repository and provide patches, features or tests.
Bugs:        Please open issues in the GitHub repository L<https://github.com/palexiou/GenOO-CLIP/issues>

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
