=head1 NAME

CLIPSeqTools::App::distribution_on_genic_elements - Measure read distribution on 5'UTR, CDS and 3'UTR.

=head1 SYNOPSIS

clipseqtools distribution_on_genic_elements [options/parameters]

=head1 DESCRIPTION

Measure the distribution of reads along transcript elements in parts of their length. 
Split the 5'UTR, CDS and 3'UTR of coding transcripts in bins and measure the read density in each bin.

=head1 OPTIONS

  Input options for library.
    --driver <Str>         driver for database connection (eg. mysql,
                           SQLite).
    --database <Str>       database name or path to database file for file
                           based databases (eg. SQLite).
    --table <Str>          database table.
    --host <Str>           hostname for database connection.
    --user <Str>           username for database connection.
    --password <Str>       password for database connection.
    --records_class <Str>  type of records stored in database.
    --filter <Filter>      filter library. May be used multiple times.
                           Syntax: column_name="pattern"
                           e.g. keep reads with deletions AND not repeat
                                masked AND longer than 31
                                --filter deletion="def" 
                                --filter rmsk="undef" .
                                --filter query_length=">31".
                           Operators: >, >=, <, <=, =, !=, def, undef

  Other input
    --gtf <Str>            GTF file with genes/transcripts.

  Output
    --o_prefix <Str>       output path prefix. Script will create and add
                           extension to path. [Default: ./]

  Other options.
    --bins <Int>           number of bins each element is split into.
                           [Default: 10]
    --length_thres <Int>   genic elements shorter than this are skipped.
                           [Default: 300]
    --plot                 call plotting script to create plots.
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
	my $reads_col = $self->reads_collection;
	
	warn "Calculating counts in bins of genic elements per transcript\n" if $self->verbose;
	my ($counted_utr5s, $counted_cdss, $counted_utr3s) = (0, 0, 0);
	my $total_copy_number = $reads_col->total_copy_number;
	foreach my $tran (@coding_transcripts) {
		$tran->extra({
			utr5_counts  => [map {'NA'} (0..$self->bins-1)],
			cds_counts   => [map {'NA'} (0..$self->bins-1)],
			utr3_counts  => [map {'NA'} (0..$self->bins-1)],
		});
		
		if (defined $tran->utr5 and $tran->utr5->exonic_length > $self->length_thres) {
			$tran->extra->{utr5_counts} = count_copy_number_in_percent_of_length_of_element(
				$tran->utr5, $reads_col, $self->bins);
			$counted_utr5s++;
		}
		
		if (defined $tran->cds and $tran->cds->exonic_length > $self->length_thres) {
			$tran->extra->{cds_counts} = count_copy_number_in_percent_of_length_of_element(
				$tran->cds, $reads_col, $self->bins);
			$counted_cdss++;
		}
		
		if (defined $tran->utr3 and $tran->utr3->exonic_length > $self->length_thres) {
			$tran->extra->{utr3_counts} = count_copy_number_in_percent_of_length_of_element(
				$tran->utr3, $reads_col, $self->bins);
			$counted_utr3s++;
		}
	};
	warn "Counted UTR5s: $counted_utr5s\n" if $self->verbose;
	warn "Counted CDSs:  $counted_cdss\n"  if $self->verbose;
	warn "Counted UTR3s: $counted_utr3s\n" if $self->verbose;
	
	warn "Creating output path\n" if $self->verbose;
	$self->make_path_for_output_prefix();
	
	warn "Printing results\n" if $self->verbose;
	open (my $OUT, '>', $self->o_prefix.'distribution_on_genic_elements.tab');
	say $OUT join("\t", 'transcript_id', 
	    (map {'utr5_bin_' . $_} (0..$self->bins-1)),
	    (map {'cds_bin_'  . $_} (0..$self->bins-1)),
	    (map {'utr3_bin_' . $_} (0..$self->bins-1))); 
	foreach my $tran (@coding_transcripts) {
		next if !defined $tran->extra;
		say $OUT join("\t", $tran->id,
			@{$tran->extra->{utr5_counts}}, 
			@{$tran->extra->{cds_counts}},
			@{$tran->extra->{utr3_counts}});
	}
	close $OUT;

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
	my ($part, $reads_col, $bins) = @_;
	
	my @counts = map{0} 0..$bins-1;
	my $longest_record_length = $reads_col->longest_record->length;
	my $part_exonic_length = $part->exonic_length;
	my $margin = int($longest_record_length/2);
	$reads_col->foreach_contained_record_do($part->strand, $part->chromosome, $part->start-$margin, $part->stop+$margin, sub {
		my ($record) = @_;
		
		my $relative_position_in_part = $part->relative_exonic_position($record->mid_position) // return 0;
		$relative_position_in_part = $part_exonic_length - $relative_position_in_part if $part->strand == -1;
		my $bin = int($bins * ($relative_position_in_part / $part->exonic_length));
		$counts[$bin] += $record->copy_number;
	});
	
	return \@counts;
}


1;
