=head1 NAME

CLIPSeqTools::App::Command::distribution_on_introns_exons - Measure read distribution on exons and introns.

=head1 SYNOPSIS

distribution_on_introns_exons.pl [options/parameters]

Measure the distribution of reads along idealized exons and introns.
Split the exons and introns of coding transcripts in bins and measure the read density in each bin.

  Input options for library.
    -type <Str>            input type (eg. DBIC, BED).
    -file <Str>            input file. Only works if type specifies a file type.
    -driver <Str>          driver for database connection (eg. mysql, SQLite). Only works if type is DBIC.
    -database <Str>        database name or path to database file for file based databases (eg. SQLite). Only works if type is DBIC.
    -table <Str>           database table. Only works if type is DBIC.
    -host <Str>            hostname for database connection. Only works if type is DBIC.
    -user <Str>            username for database connection. Only works if type is DBIC.
    -password <Str>        password for database connection. Only works if type is DBIC.
    -records_class <Str>   type of records stored in database (Default: GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3).
    -filter <Filter>       filter library. Option can be given multiple times.
                           Filter syntax: column_name="pattern"
                             e.g. -filter deletion="def" -filter rmsk="undef" to keep reads with deletions and not repeat masked.
                             e.g. -filter query_length=">31" -filter query_length="<=50" to keep reads longer than 31 and shorter or   equal to 50.
                           Supported operators: ">", ">=", "<", "<=", "=", "!=","def", "undef"

  Other input
    -gtf <Str>             GTF file with genes/transcripts.

  Output
    -o_prefix <Str>        output path prefix. Script adds an extension to path. If path does not exist it will be created. Default: ./

  Other options.
    -bins <Int>            the number of bins to divide the length of each element. Default: 10
    -length_thres <Int>    genic elements shorter than this are skipped. Default: 300
    -v --verbose           print progress lines and extra information.
    -h -? --usage --help   print help message

=head1 DESCRIPTION

Measure the distribution of reads along idealized exons and introns.
Split the exons and introns of coding transcripts in bins and measure the read density in each bin.

=cut

package CLIPSeqTools::App::Command::distribution_on_introns_exons;


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use Moose;
use namespace::autoclean;
use File::Spec;
use List::Util qw(sum max);


extends 'MooseX::App::Cmd::Command'; # Declare that class is a command


#######################################################################
#######################   Command line options   ######################
#######################################################################
has 'bins' => (
	is            => 'rw',
	isa           => 'Int',
	traits        => ['Getopt'],
	default       => 10,
	documentation => 'the number of bins to divide the length of each element. Default: 10',
);

has 'length_thres' => (
	is            => 'rw',
	isa           => 'Int',
	traits        => ['Getopt'],
	default       => 300,
	documentation => 'genic elements shorter than this are skipped. Default: 300',
);


#######################################################################
##########################   Consume Roles   ##########################
#######################################################################
with 
	"CLIPSeqTools::Role::ReadsCollectionInput" => {
		-alias    => { validate_args => '_validate_args_for_reads_collection_input' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::TranscriptCollectionInput" => {
		-alias    => { validate_args => '_validate_args_for_transcriptcollection_input' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::OutputPrefixOption" => {
		-alias    => { validate_args => '_validate_args_for_output_prefix_option' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::VerbosityOption" => {
		-alias    => { validate_args => '_validate_args_for_verbosity_option' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::HelpOption" => {
		-alias    => { validate_args => '_check_help_flag' },
		-excludes => 'validate_args',
	};

	
#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub description {
	q(Measure the distribution of reads along idealized exons and introns.)."\n". 
	q(Split the exons and introns of coding transcripts in bins and measure the read density in each bin.);
}

sub validate_args {
	my ($self, $opt, $args) = @_;
	
	$self->_check_help_flag;
	$self->_validate_args_for_reads_collection_input;
	$self->_validate_args_for_transcriptcollection_input;
	$self->_validate_args_for_output_prefix_option;
	$self->_validate_args_for_verbosity_option;
}

sub execute {
	my ($self, $opt, $args) = @_;
	
	warn "Creating transcript collection\n" if $self->verbose;
	my $transcript_collection = $self->transcript_collection;
	my @coding_transcripts = grep{$_->is_coding} $transcript_collection->all_records;

	warn "Creating reads collection\n" if $self->verbose;
	my $reads_collection = $self->reads_collection;

	warn "Measuring reads in bins of introns/exons per transcript\n" if $self->verbose;
	my (@exon_binned_reads, @intron_binned_reads, @exon_binned_reads_per_nt, @intron_binned_reads_per_nt);
	my ($counted_exons, $counted_introns) = (0, 0);
	foreach my $transcript (@coding_transcripts) {
		foreach my $exon (@{$transcript->exons}) {
			my $exon_counts = count_copy_number_in_percent_of_length_of_element($exon, $reads_collection, $self->bins);
			map{ $exon_binned_reads[$_] += $exon_counts->[$_] } 0..$self->bins-1;
			map{ $exon_binned_reads_per_nt[$_] += $exon_counts->[$_] / ($exon->length || 1) } 0..$self->bins-1;
			$counted_exons++;
		}
		
		foreach my $intron (@{$transcript->introns}) {
			my $intron_counts = count_copy_number_in_percent_of_length_of_element($intron, $reads_collection, $self->bins);
			map{ $intron_binned_reads[$_] += $intron_counts->[$_] } 0..$self->bins-1;
			map{ $intron_binned_reads_per_nt[$_] += $intron_counts->[$_] / ($intron->length || 1) } 0..$self->bins-1;
			$counted_introns++;
		}
	};
	warn "Counted exons:   $counted_exons\n" if $self->verbose;
	warn "Counted introns: $counted_introns\n" if $self->verbose;

	warn "Averaging the counts accross all transcripts\n" if $self->verbose;
	my @exon_binned_mean_reads = map{$_/$counted_exons} @exon_binned_reads;
	my @intron_binned_mean_reads = map{$_/$counted_introns} @intron_binned_reads;
	my @exon_binned_mean_reads_per_nt = map{$_/$counted_exons} @exon_binned_reads_per_nt;
	my @intron_binned_mean_reads_per_nt = map{$_/$counted_introns} @intron_binned_reads_per_nt;

	warn "Normalizing by library size (RPKM)\n" if $self->verbose;
	my $total_copy_number = $reads_collection->total_copy_number;
	my @exon_binned_mean_percent_reads_per_nt = map{($_/$total_copy_number) * 10**9} @exon_binned_mean_reads_per_nt;
	my @intron_binned_mean_percent_reads_per_nt = map{($_/$total_copy_number) * 10**9} @intron_binned_mean_reads_per_nt;

	warn "Creating output path\n" if $self->verbose;
	$self->make_path_for_output_prefix();

	warn "Printing results\n" if $self->verbose;
	open (my $OUT, '>', $self->o_prefix.'distribution_on_introns_exons.tab');
	say $OUT join("\t", 'bin', 'element', 'avg_counts', 'avg_counts_per_nt', 'avg_rpkm');
	foreach my $bin (0..$self->bins-1) {
		say $OUT join("\t", $bin, 'exon', $exon_binned_mean_reads[$bin], $exon_binned_mean_reads_per_nt[$bin], $exon_binned_mean_percent_reads_per_nt[$bin]);
	}
	foreach my $bin (0..$self->bins-1) {
		say $OUT join("\t", $bin, 'intron', $intron_binned_mean_reads[$bin], $intron_binned_mean_reads_per_nt[$bin], $intron_binned_mean_percent_reads_per_nt[$bin]);
	}
}


#######################################################################
############################   Functions   ############################
#######################################################################
sub count_copy_number_in_percent_of_length_of_element {
	my ($part, $reads_collection, $bins) = @_;
	
	my @counts = map{0} 0..$bins-1;
	my $longest_record_length = $reads_collection->longest_record->length;
	my $margin = int($longest_record_length/2);
	$reads_collection->foreach_contained_record_do($part->strand, $part->chromosome, $part->start-$margin, $part->stop+$margin, sub {
		my ($record) = @_;
		
		return 0 if !$part->overlaps($record);
		
		my $bin = int($bins * (abs($part->head_mid_distance_from($record)) / $part->length));
		$counts[$bin] += $record->copy_number;
	});
	
	return \@counts;
}

1;
