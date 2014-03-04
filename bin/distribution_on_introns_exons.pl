#!/usr/bin/env perl

=head1 NAME

distribution_on_genic_elements.pl

=head1 SYNOPSIS

distribution_on_genic_elements.pl [options/parameters]

Measure the distribution of reads along idealized introns and exons. Split the introns and exons of coding transcripts in bins and measure the read density in each bin.

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

Measure the distribution of reads along idealized introns and exons. Split the introns and exons of coding transcripts in bins and measure the read density in each bin.

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
warn "Measuring reads in bins of introns/exons per transcript\n" if $verbose;
my (@exon_binned_reads, @intron_binned_reads, @exon_binned_reads_per_nt, @intron_binned_reads_per_nt);
my ($counted_exons, $counted_introns) = (0, 0);
foreach my $transcript (@coding_transcripts) {
	foreach my $exon (@{$transcript->exons}) {
		my $exon_counts = count_copy_number_in_percent_of_length_of_element($exon, $reads_collection, $bins);
		map{ $exon_binned_reads[$_] += $exon_counts->[$_] } 0..$bins-1;
		map{ $exon_binned_reads_per_nt[$_] += $exon_counts->[$_] / ($exon->length || 1) } 0..$bins-1;
		$counted_exons++;
	}
	
	foreach my $intron (@{$transcript->introns}) {
		my $intron_counts = count_copy_number_in_percent_of_length_of_element($intron, $reads_collection, $bins);
		map{ $intron_binned_reads[$_] += $intron_counts->[$_] } 0..$bins-1;
		map{ $intron_binned_reads_per_nt[$_] += $intron_counts->[$_] / ($intron->length || 1) } 0..$bins-1;
		$counted_introns++;
	}
};
warn "Counted exons:   $counted_exons\n" if $verbose;
warn "Counted introns: $counted_introns\n" if $verbose;


##############################################
warn "Averaging the counts accross all transcripts\n" if $verbose;
my @exon_binned_mean_reads = map{$_/$counted_exons} @exon_binned_reads;
my @intron_binned_mean_reads = map{$_/$counted_introns} @intron_binned_reads;
my @exon_binned_mean_reads_per_nt = map{$_/$counted_exons} @exon_binned_reads_per_nt;
my @intron_binned_mean_reads_per_nt = map{$_/$counted_introns} @intron_binned_reads_per_nt;


##############################################
warn "Normalizing by library size (RPKM)\n" if $verbose;
my $total_copy_number = $reads_collection->total_copy_number;
my @exon_binned_mean_percent_reads_per_nt = map{($_/$total_copy_number) * 10**9} @exon_binned_mean_reads_per_nt;
my @intron_binned_mean_percent_reads_per_nt = map{($_/$total_copy_number) * 10**9} @intron_binned_mean_reads_per_nt;


#################################
warn "Creating output path\n" if $verbose;
my (undef, $directory, undef) = File::Spec->splitpath($o_file); make_path($directory);


##############################################
warn "Printing results\n" if $verbose;
open (my $OUT, '>', $o_file);
say $OUT join("\t", 'bin', 'element', 'avg_counts', 'avg_counts_per_nt', 'avg_rpkm');
foreach my $bin (0..$bins-1) {
	say $OUT join("\t", $bin, 'exon', $exon_binned_mean_reads[$bin], $exon_binned_mean_reads_per_nt[$bin], $exon_binned_mean_percent_reads_per_nt[$bin]);
}
foreach my $bin (0..$bins-1) {
	say $OUT join("\t", $bin, 'intron', $intron_binned_mean_reads[$bin], $intron_binned_mean_reads_per_nt[$bin], $intron_binned_mean_percent_reads_per_nt[$bin]);
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
	my $margin = int($longest_record_length/2);
	$reads_collection->foreach_contained_record_do($part->strand, $part->chromosome, $part->start-$margin, $part->stop+$margin, sub {
		my ($record) = @_;
		
		return 0 if !$part->overlaps($record);
		
		my $bin = int($bins * (abs($part->head_mid_distance_from($record)) / $part->length));
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
