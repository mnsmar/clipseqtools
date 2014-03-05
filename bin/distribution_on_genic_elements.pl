#!/usr/bin/env perl

=head1 NAME

distribution_on_genic_elements.pl

=head1 SYNOPSIS

distribution_on_genic_elements.pl [options/parameters]

Measure the distribution of reads along idealized transcript elements. Split the 5'UTR, CDS and 3'UTR of coding transcripts in bins and measure the read density in each bin.

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

  Other input.
      -gtf <Str>             GTF file for transcripts.

  Output.
      -o_file <Str>          filename for output file. If path does not exist it will be created.

  Input Filters (only for DBIC input type).
      -filter <Filter>       filter library. Option can be given multiple times.
                             Filter syntax: column_name="pattern"
                               e.g. -filter deletion="def" -filter rmsk="undef" to keep reads with deletions and not repeat masked.
                               e.g. -filter query_length=">31" -filter query_length="<=50" to keep reads longer than 31 and shorter or   equal to 50.
                             Supported operators: ">", ">=", "<", "<=", "=", "!=","def", "undef"

  Other options.
      -bins <Int>            the number of bins to divide the length of each element.
      -v                     verbosity. If used progress lines are printed.
      -h                     print help message
      -man                   show man page


=head1 DESCRIPTION

Measure the distribution of reads along idealized transcript elements. Divide the 5'UTR, CDS and 3'UTR of coding transcripts in bins and measure the read density in each bin.

=cut


##############################################
# Import external libraries
use Modern::Perl;
use autodie;
use Getopt::Long;
use Pod::Usage;
use File::Path qw(make_path);
use File::Spec;


##############################################
# Import GenOO
use GenOO::RegionCollection::Factory;
use GenOO::TranscriptCollection::Factory;


##############################################
# Read command options
my $bins = 10;
my $min_genic_element_length = 300;
my $type = 'DBIC';
my $records_class = 'GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3';

GetOptions(
# Input options for library.
	'type=s'          => \$type,
	'file=s'          => \my $file,
	'driver=s'        => \my $driver,
	'host=s'          => \my $host,
	'database=s'      => \my $database,
	'table=s'         => \my $table,
	'user=s'          => \my $user,
	'password=s'      => \my $pass,
	'records_class=s' => \$records_class,
# Other input
	'gtf=s'           => \my $gtf_file,
# Output
	'o_file=s'        => \my $o_file,
# Input Filters (only for DBIC input type)
	'filter=s'        => \my @filters, # eg. -filter deletion="def" -filter score="!=100"
# Other options
	'bins=i'          => \$bins,
	'length_thres=i'  => \$min_genic_element_length,
	'h'               => \my $help,
	'man'             => \my $man,
	'v'               => \my $verbose,
) or pod2usage({-verbose => 0});

pod2usage(-verbose => 1)  if $help;
pod2usage(-verbose => 2)  if $man;


##############################################
warn "Creating transcript collection\n" if $verbose;
my $transcript_collection = read_transcript_collection($gtf_file);
my @coding_transcripts = grep{$_->is_coding} $transcript_collection->all_records;


##############################################
warn "Creating reads collection\n" if $verbose;
my $reads_collection = read_collection($type, $file, $driver, $database, $table, $records_class, $host, $user, $pass);
apply_simple_filters($reads_collection, \@filters) if $type eq 'DBIC';


##############################################
warn "Calculating counts in bins of genic elements per transcript\n" if $verbose;
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
	if (defined $transcript->utr5 and $transcript->utr5->exonic_length > $min_genic_element_length) {
		my $utr5_counts = count_copy_number_in_percent_of_length_of_element($transcript->utr5, $reads_collection, $bins);
		map{ $utr5_binned_reads[$_] += $utr5_counts->[$_] } 0..$bins-1;
		map{ $utr5_binned_reads_per_nt[$_] += $utr5_counts->[$_] / ($transcript->utr5->exonic_length || 1) } 0..$bins-1;
		$counted_utr5s++;
	}
	
	if (defined $transcript->cds and $transcript->cds->exonic_length > $min_genic_element_length) {
		my $cds_counts = count_copy_number_in_percent_of_length_of_element($transcript->cds, $reads_collection, $bins);
		map{ $cds_binned_reads[$_]  += $cds_counts->[$_]  } 0..$bins-1;
		map{ $cds_binned_reads_per_nt[$_]  += $cds_counts->[$_]  / ($transcript->cds->exonic_length  || 1)  } 0..$bins-1;
		$counted_cdss++;
	}
	
	if (defined $transcript->utr3 and $transcript->utr3->exonic_length > $min_genic_element_length) {
		my $utr3_counts = count_copy_number_in_percent_of_length_of_element($transcript->utr3, $reads_collection, $bins);
		map{ $utr3_binned_reads[$_] += $utr3_counts->[$_] } 0..$bins-1;
		map{ $utr3_binned_reads_per_nt[$_] += $utr3_counts->[$_] / ($transcript->utr3->exonic_length || 1) } 0..$bins-1;
		$counted_utr3s++;
	}
};
warn "Counted UTR5s: $counted_utr5s\n" if $verbose;
warn "Counted CDSs:  $counted_cdss\n"  if $verbose;
warn "Counted UTR3s: $counted_utr3s\n" if $verbose;


##############################################
warn "Averaging the counts into element arrays\n" if $verbose;
my @utr5_binned_mean_reads = map{$_/$counted_utr5s} @utr5_binned_reads;
my @cds_binned_mean_reads = map{$_/$counted_cdss} @cds_binned_reads;
my @utr3_binned_mean_reads = map{$_/$counted_utr3s} @utr3_binned_reads;
my @utr5_binned_mean_reads_per_nt = map{$_/$counted_utr5s} @utr5_binned_reads_per_nt;
my @cds_binned_mean_reads_per_nt = map{$_/$counted_cdss} @cds_binned_reads_per_nt;
my @utr3_binned_mean_reads_per_nt = map{$_/$counted_utr3s} @utr3_binned_reads_per_nt;


##############################################
warn "Normalizing by library size (RPKM)\n" if $verbose;
my $total_copy_number = $reads_collection->total_copy_number;
my @utr5_binned_mean_percent_reads_per_nt = map{($_/$total_copy_number) * 10**9} @utr5_binned_mean_reads_per_nt;
my @cds_binned_mean_percent_reads_per_nt = map{($_/$total_copy_number) * 10**9} @cds_binned_mean_reads_per_nt;
my @utr3_binned_mean_percent_reads_per_nt = map{($_/$total_copy_number) * 10**9} @utr3_binned_mean_reads_per_nt;


#################################
warn "Creating output path\n" if $verbose;
my (undef, $directory, undef) = File::Spec->splitpath($o_file); make_path($directory);


##############################################
warn "Printing results\n" if $verbose;
open (my $OUT, '>', $o_file);
say $OUT join("\t", 'bin', 'element', 'avg_counts', 'avg_counts_per_nt', 'avg_rpkm');
foreach my $bin (0..$bins-1) {
	say $OUT join("\t", $bin, 'utr5', $utr5_binned_mean_reads[$bin], $utr5_binned_mean_reads_per_nt[$bin], $utr5_binned_mean_percent_reads_per_nt[$bin]);
}
foreach my $bin (0..$bins-1) {
	say $OUT join("\t", $bin, 'cds', $cds_binned_mean_reads[$bin], $cds_binned_mean_reads_per_nt[$bin], $cds_binned_mean_percent_reads_per_nt[$bin]);
}
foreach my $bin (0..$bins-1) {
	say $OUT join("\t", $bin, 'utr3', $utr3_binned_mean_reads[$bin], $utr3_binned_mean_reads_per_nt[$bin], $utr3_binned_mean_percent_reads_per_nt[$bin]);
}


###########################################
# Subroutines used
###########################################
sub read_transcript_collection {
	my ($gtf_file) = @_;
	
	pod2usage(-verbose => 1, -message => "$0: GTF file is required.\n") if !$gtf_file;
	
	return GenOO::TranscriptCollection::Factory->create('GTF', {
		file => $gtf_file
	})->read_collection;
}

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

sub read_collection {
	my ($type, $file, $driver, $database, $table, $records_class, $host, $user, $pass) = @_;
	
	return read_collection_from_file($file) if $type =~ /^BED$/;
	return read_collection_from_database($driver, $database, $table, $records_class, $host, $user, $pass) if $type =~ /^DBIC$/;
	
	pod2usage(-verbose => 1, -message => "$0: Unknown or no input type specified.\n");
}

sub read_collection_from_file {
	my ($file) = @_;
	
	pod2usage(-verbose => 1, -message => "$0: File is required.\n") if !$file;

	return GenOO::RegionCollection::Factory->create('BED', {
		file => $file
	})->read_collection;
}

sub read_collection_from_database {
	my ($driver, $database, $table, $records_class, $host, $user, $pass) = @_;
	
	pod2usage(-verbose => 1, -message => "$0: Driver for database connection is required.\n") if !$driver;
	pod2usage(-verbose => 1, -message => "$0: Database name or path is required.\n") if !$database;
	pod2usage(-verbose => 1, -message => "$0: Database table is required.\n") if !$table;
	
	return GenOO::RegionCollection::Factory->create('DBIC', {
		driver        => $driver,
		host          => $host,
		database      => $database,
		user          => $user,
		password      => $pass,
		table         => $table,
		records_class => $records_class,
	})->read_collection;
}

sub apply_simple_filters {
	my ($collection, $params) = @_;
	
	foreach my $element (@$params) {
		$element =~ /^(.+?)=(.+?)$/;
		my $col_name = $1;
		my $filter   = $2;
		$collection->simple_filter($col_name, $filter);
	}
}
