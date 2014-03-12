=head1 NAME

CLIPSeqTools::Role::GeneCollectionInput - Role to enable reading a GTF file with genes/transcripts from the command line

=head1 SYNOPSIS

Role to enable reading a GTF file with genes/transcripts from the command line

  Defines options.
      -gtf <Str>               GTF file for transcripts.

  Provides attributes.
      gene_collection          the collection of genes that is read from the GTF
      transcript_collection    the collection of transcripts that is read from the GTF

=cut


package CLIPSeqTools::Role::GeneCollectionInput;


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use Moose::Role;
use MooseX::App::Role;


#######################################################################
########################   Load GenOO modules   #######################
#######################################################################
use GenOO::GeneCollection::Factory;
use GenOO::TranscriptCollection::Factory;


#######################################################################
#######################   Command line options   ######################
#######################################################################
option 'gtf' => (
	is            => 'rw',
	isa           => 'Str',
	documentation => 'GTF file with genes/transcripts',
);


#######################################################################
######################   Interface Attributes   #######################
#######################################################################
has 'gene_collection' => (
	traits    => ['NoGetopt'],
	is        => 'rw',
	builder   => '_read_gene_collection',
	lazy      => 1,
);

has 'transcript_collection' => (
	traits    => ['NoGetopt'],
	is        => 'rw',
	builder   => '_read_transcript_collection',
	lazy      => 1,
);


#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {
	my ($self) = @_;
	
	$self->usage_error('GTF file with genes/transcripts is required') if !$self->gtf;
}


#######################################################################
#########################   Private Methods   #########################
#######################################################################
sub _read_gene_collection {
	my ($self) = @_;
	
	return GenOO::GeneCollection::Factory->create('GTF', {
		file => $self->gtf
	})->read_collection;
}

sub _read_transcript_collection {
	my ($self) = @_;
	
	return GenOO::TranscriptCollection::Factory->create('FromGeneCollection', {
		gene_collection => $self->gene_collection
	})->read_collection;
}


1;
