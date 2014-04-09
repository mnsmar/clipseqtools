=head1 NAME

CLIPSeqTools::App::distribution_on_genic_elements - Measure read distribution on 5'UTR, CDS and 3'UTR.

=head1 SYNOPSIS

clipseqtools distribution_on_genic_elements [options/parameters]

=head1 DESCRIPTION

Measure the distribution of reads along idealized transcript elements. 
Split the 5'UTR, CDS and 3'UTR of coding transcripts in bins and measure the read density in each bin.

=head1 OPTIONS

  Input options for library.
    -driver <Str>          driver for database connection (eg. mysql,
                           SQLite).
    -database <Str>        database name or path to database file for file
                           based databases (eg. SQLite).
    -table <Str>           database table.
    -host <Str>            hostname for database connection.
    -user <Str>            username for database connection.
    -password <Str>        password for database connection.
    -records_class <Str>   type of records stored in database.
    -filter <Filter>       filter library. May be used multiple times.
                           Syntax: column_name="pattern"
                           e.g. keep reads with deletions AND not repeat
                                masked AND longer than 31
                                -filter deletion="def" 
                                -filter rmsk="undef" .
                                -filter query_length=">31".
                           Operators: >, >=, <, <=, =, !=, def, undef

  Other input
    -gtf <Str>             GTF file with genes/transcripts.

  Output
    -o_prefix <Str>        output path prefix. Script will create and add
                           extension to path. Default: ./

  Other options.
    -bins <Int>            number of bins each element is split into.
                           Default: 10
    -length_thres <Int>    genic elements shorter than this are skipped.
                           Default: 300
    -plot                  call plotting script to create plots.
    -v --verbose           print progress lines and extra information.
    -h -? --usage --help   print help message
    
=cut

package CLIPSeqTools::App::distribution_on_genic_elements;


# Make it an app command
use MooseX::App::Command;
extends 'CLIPSeqTools::App';


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use namespace::autoclean;


#######################################################################
#######################   Command line options   ######################
#######################################################################
option 'bins' => (
	is            => 'rw',
	isa           => 'Int',
	default       => 10,
	documentation => 'number of bins each element is split into.',
);

option 'length_thres' => (
	is            => 'rw',
	isa           => 'Int',
	default       => 300,
	documentation => 'genic elements shorter than this are skipped.',
);


#######################################################################
##########################   Consume Roles   ##########################
#######################################################################
with 
	"CLIPSeqTools::Role::Option::Library" => {
		-alias    => { validate_args => '_validate_args_for_library' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::Option::Transcripts" => {
		-alias    => { validate_args => '_validate_args_for_transcripts' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::Option::Plot" => {
		-alias    => { validate_args => '_validate_args_for_plot' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::Option::OutputPrefix" => {
		-alias    => { validate_args => '_validate_args_for_output_prefix' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::Option::Verbosity" => {
		-alias    => { validate_args => '_validate_args_for_verbosity' },
		-excludes => 'validate_args',
	};

	
#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {
	my ($self) = @_;
	
	$self->_validate_args_for_library;
	$self->_validate_args_for_transcripts;
	$self->_validate_args_for_plot;
	$self->_validate_args_for_output_prefix;
	$self->_validate_args_for_verbosity;
}

sub run {
	my ($self) = @_;
	
	warn "Starting analysis: distribution_on_genic_elements\n";
	
	warn "Validating arguments\n" if $self->verbose;
	$self->validate_args();
	
	warn "Creating transcript collection\n" if $self->verbose;
	my $transcript_collection = $self->transcript_collection;
	my @coding_transcripts = grep{$_->is_coding} $transcript_collection->all_records;
	
	warn "Creating reads collection\n" if $self->verbose;
	my $reads_collection = $self->reads_collection;
	
	warn "Calculating counts in bins of genic elements per transcript\n" if $self->verbose;
	my (@utr5_binned_reads,
		@cds_binned_reads,
		@utr3_binned_reads,
		@utr5_binned_reads_per_nt,
		@cds_binned_reads_per_nt,
		@utr3_binned_reads_per_nt);
	my ($counted_utr5s,
		$counted_cdss,
		$counted_utr3s) = (0, 0, 0);
	foreach my $transcript (@coding_transcripts) {
		if (defined $transcript->utr5 and $transcript->utr5->exonic_length > $self->length_thres) {
			my $utr5_counts = count_copy_number_in_percent_of_length_of_element($transcript->utr5, $reads_collection, $self->bins);
			map{ $utr5_binned_reads[$_] += $utr5_counts->[$_] } 0..$self->bins-1;
			map{ $utr5_binned_reads_per_nt[$_] += $utr5_counts->[$_] / ($transcript->utr5->exonic_length || 1) } 0..$self->bins-1;
			$counted_utr5s++;
		}
		
		if (defined $transcript->cds and $transcript->cds->exonic_length > $self->length_thres) {
			my $cds_counts = count_copy_number_in_percent_of_length_of_element($transcript->cds, $reads_collection, $self->bins);
			map{ $cds_binned_reads[$_]  += $cds_counts->[$_]  } 0..$self->bins-1;
			map{ $cds_binned_reads_per_nt[$_]  += $cds_counts->[$_]  / ($transcript->cds->exonic_length  || 1)  } 0..$self->bins-1;
			$counted_cdss++;
		}
		
		if (defined $transcript->utr3 and $transcript->utr3->exonic_length > $self->length_thres) {
			my $utr3_counts = count_copy_number_in_percent_of_length_of_element($transcript->utr3, $reads_collection, $self->bins);
			map{ $utr3_binned_reads[$_] += $utr3_counts->[$_] } 0..$self->bins-1;
			map{ $utr3_binned_reads_per_nt[$_] += $utr3_counts->[$_] / ($transcript->utr3->exonic_length || 1) } 0..$self->bins-1;
			$counted_utr3s++;
		}
	};
	warn "Counted UTR5s: $counted_utr5s\n" if $self->verbose;
	warn "Counted CDSs:  $counted_cdss\n"  if $self->verbose;
	warn "Counted UTR3s: $counted_utr3s\n" if $self->verbose;
	
	warn "Averaging the counts into element arrays\n" if $self->verbose;
	my @utr5_binned_mean_reads = map{$_/$counted_utr5s} @utr5_binned_reads;
	my @cds_binned_mean_reads = map{$_/$counted_cdss} @cds_binned_reads;
	my @utr3_binned_mean_reads = map{$_/$counted_utr3s} @utr3_binned_reads;
	my @utr5_binned_mean_reads_per_nt = map{$_/$counted_utr5s} @utr5_binned_reads_per_nt;
	my @cds_binned_mean_reads_per_nt = map{$_/$counted_cdss} @cds_binned_reads_per_nt;
	my @utr3_binned_mean_reads_per_nt = map{$_/$counted_utr3s} @utr3_binned_reads_per_nt;
	
	warn "Normalizing by library size (RPKM)\n" if $self->verbose;
	my $total_copy_number = $reads_collection->total_copy_number;
	my @utr5_binned_mean_percent_reads_per_nt = map{($_/$total_copy_number) * 10**9} @utr5_binned_mean_reads_per_nt;
	my @cds_binned_mean_percent_reads_per_nt = map{($_/$total_copy_number) * 10**9} @cds_binned_mean_reads_per_nt;
	my @utr3_binned_mean_percent_reads_per_nt = map{($_/$total_copy_number) * 10**9} @utr3_binned_mean_reads_per_nt;

	warn "Creating output path\n" if $self->verbose;
	$self->make_path_for_output_prefix();
	
	warn "Printing results\n" if $self->verbose;
	open (my $OUT, '>', $self->o_prefix.'distribution_on_genic_elements.tab');
	say $OUT join("\t", 'bin', 'element', 'avg_counts', 'avg_counts_per_nt', 'avg_rpkm');
	foreach my $bin (0..$self->bins-1) {
		say $OUT join("\t", $bin, 'utr5', $utr5_binned_mean_reads[$bin], $utr5_binned_mean_reads_per_nt[$bin], $utr5_binned_mean_percent_reads_per_nt[$bin]);
	}
	foreach my $bin (0..$self->bins-1) {
		say $OUT join("\t", $bin, 'cds', $cds_binned_mean_reads[$bin], $cds_binned_mean_reads_per_nt[$bin], $cds_binned_mean_percent_reads_per_nt[$bin]);
	}
	foreach my $bin (0..$self->bins-1) {
		say $OUT join("\t", $bin, 'utr3', $utr3_binned_mean_reads[$bin], $utr3_binned_mean_reads_per_nt[$bin], $utr3_binned_mean_percent_reads_per_nt[$bin]);
	}
	
	if ($self->plot) {
		warn "Creating plot\n" if $self->verbose;
		CLIPSeqTools::PlotApp->initialize_command_class('CLIPSeqTools::PlotApp::distribution_on_genic_elements', 
			file     => $self->o_prefix.'distribution_on_genic_elements.tab',
			o_prefix => $self->o_prefix
		)->run();
	}
}


#######################################################################
############################   Functions   ############################
#######################################################################
sub count_copy_number_in_percent_of_length_of_element {
	my ($part, $reads_collection, $bins) = @_;
	
	my @counts = map{0} 0..$bins-1;
	my $longest_record_length = $reads_collection->longest_record->length;
	my $part_exonic_length = $part->exonic_length;
	my $margin = int($longest_record_length/2);
	$reads_collection->foreach_contained_record_do($part->strand, $part->chromosome, $part->start-$margin, $part->stop+$margin, sub {
		my ($record) = @_;
		
		my $relative_position_in_part = $part->relative_exonic_position($record->mid_position) // return 0;
		$relative_position_in_part = $part_exonic_length - $relative_position_in_part if $part->strand == -1;
		my $bin = int($bins * ($relative_position_in_part / $part->exonic_length));
		$counts[$bin] += $record->copy_number;
	});
	
	return \@counts;
}


1;
