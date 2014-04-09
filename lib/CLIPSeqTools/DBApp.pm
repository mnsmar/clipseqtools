# POD documentation - main docs before the code

=head1 NAME

CLIPSeqTools::DBApp - Tools for creation/management of database tables with CLIP-Seq data.

=head1 SYNOPSIS

CLIPSeqTools::DBApp provides tools for creation/management of database tables with CLIP-Seq data.

=head1 DESCRIPTION

CLIPSeqTools::DBApp consists of a collection of scripts and modules that
can be used for the creation and management of databases tables that
contain CLIP-Seq data and are compatible with CLIPSeqTools applications.
It provides tools to convert SAM files to database tables and to annotate
these tables with infromation such as transcripts, 3'UTRs, repeats etc.

=head1 EXAMPLES

=cut


package CLIPSeqTools::DBApp;


# Make it an App and load plugins
use Moose;
extends 'CLIPSeqTools::App';


1;
