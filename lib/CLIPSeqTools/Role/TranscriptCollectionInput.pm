=head1 NAME

CLIPSeqTools::Role::TranscriptCollectionInput - Role to enable reading a GTF file with transcripts from the command line

=head1 SYNOPSIS

Role to enable reading a GTF file with transcripts from the command line

  Defines options.
      -gtf <Str>               GTF file for transcripts.

  Provides attributes.
      transcript_collection    the collection of transcripts that is read from the GTF

=cut


package CLIPSeqTools::Role::TranscriptCollectionInput;


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use Moose::Role;


#######################################################################
########################   Load GenOO modules   #######################
#######################################################################
use GenOO::TranscriptCollection::Factory;


#######################################################################
#######################   Command line options   ######################
#######################################################################
has 'gtf' => (
	is            => 'rw',
	isa           => 'Str',
	traits        => ['Getopt'],
	documentation => 'GTF file with transcripts',
);


#######################################################################
######################   Interface Attributes   #######################
#######################################################################
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
	
	$self->usage_error('GTF file with transcripts is required') if !$self->gtf;
}


#######################################################################
#########################   Private Methods   #########################
#######################################################################
sub _read_transcript_collection {
	my ($self) = @_;
	
	return GenOO::TranscriptCollection::Factory->create('GTF', {
		file => $self->gtf
	})->read_collection;
}

1;
