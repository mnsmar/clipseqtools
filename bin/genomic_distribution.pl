#!/usr/bin/env perl

=head1 NAME

genomic_distribution.pl

=head1 SYNOPSIS

genomic_distribution.pl [options/parameters]

Measure the number of reads that align to each genome wide annotation (e.g. genic, intergenic, repeats, exonic, intronic, etc).

  Input options for library.
      -driver <Str>          driver for database connection (eg. mysql, SQLite).
      -database <Str>        database name or path to database file for file based databases.
      -table <Str>           database table.
      -host <Str>            hostname for database connection.
      -user <Str>            username for database connection.
      -password <Str>        password for database connection.
      -records_class <Str>   type of records stored in database (Default: GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3).

  Output.
      -o_file <Str>          filename for output file. If path does not exist it will be created.

  Input Filters (only for DBIC input type).
      -filter <Filter>       filter library. Option can be given multiple times.
                             Filter syntax: column_name="pattern"
                               e.g. -filter deletion="def" -filter rmsk="undef" to keep reads with deletions and not repeat masked.
                               e.g. -filter query_length=">31" -filter query_length="<=50" to keep reads longer than 31 and shorter or   equal to 50.
                             Supported operators: ">", ">=", "<", "<=", "=", "!=","def", "undef"

  Other options.
      -v                     verbosity. If used progress lines are printed.
      -h                     print help message
      -man                   show man page


=head1 DESCRIPTION

Measure the number of reads that align to each genome wide annotation (e.g. genic, intergenic, repeats, exonic, intronic, etc).

=cut


##############################################
# Import external libraries
use Modern::Perl;
use autodie;
use Getopt::Long;
use Pod::Usage;
use File::Path qw(make_path);


##############################################
# Import GenOO
use GenOO::RegionCollection::Factory;


##############################################
# Read command options
my $records_class = 'GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3';

GetOptions(
# Input options for library.
	'driver=s'        => \my $driver,
	'host=s'          => \my $host,
	'database=s'      => \my $database,
	'table=s'         => \my $table,
	'user=s'          => \my $user,
	'password=s'      => \my $pass,
	'records_class=s' => \$records_class,
# Output
	'o_file=s'        => \my $o_file,
# Input Filters
	'filter=s'        => \my @filters, # eg. -filter deletion="def" -filter score="!=100"
# Other options
	'h'               => \my $help,
	'man'             => \my $man,
	'v'               => \my $verbose,
) or pod2usage({-verbose => 0});

pod2usage(-verbose => 1)  if $help;
pod2usage(-verbose => 2)  if $man;


##############################################
warn "Checking the input\n" if $verbose;
check_options_and_arguments();


##############################################
warn "Creating reads collection\n" if $verbose;
my $reads_collection = read_collection('DBIC', undef, $driver, $database, $table, $records_class, $host, $user, $pass);
apply_simple_filters($reads_collection, \@filters);
$reads_collection->schema->storage->debug(1) if $verbose;


##############################################
warn "Preparing reads resultset\n" if $verbose;
my $reads_rs = $reads_collection->resultset;


##############################################
warn "Counting reads for each annotation\n" if $verbose;
my %counts;

$counts{'total'} = $reads_rs->get_column('copy_number')->sum;

$counts{'repeats'} = $reads_rs->search({
	rmsk => {'!=', undef}
})->get_column('copy_number')->sum;

$counts{'intergenic'} = $reads_rs->search({
	transcript => undef,
	rmsk => undef
})->get_column('copy_number')->sum;

$counts{'genic'} = $reads_rs->search({
	transcript => {'!=', undef},
})->get_column('copy_number')->sum;

$counts{'exonic'} = $reads_rs->search({
	transcript => {'!=', undef},
	exon       => {'!=', undef},
})->get_column('copy_number')->sum;

$counts{'intronic'} = $reads_rs->search({
	transcript => {'!=', undef},
	exon       => undef,
})->get_column('copy_number')->sum;

$counts{'genic-norepeat'} = $reads_rs->search({
	transcript => {'!=', undef},
	rmsk       => undef
})->get_column('copy_number')->sum;

$counts{'exonic-norepeat'} = $reads_rs->search({
	exon => {'!=', undef},
	rmsk => undef
})->get_column('copy_number')->sum;

$counts{'intronic-norepeat'} = $reads_rs->search({
	transcript => {'!=', undef},
	exon       => undef,
	rmsk       => undef
})->get_column('copy_number')->sum;

# Coding transcripts
$counts{'genic-coding-norepeat'} = $reads_rs->search({
	coding_transcript => {'!=', undef},
	rmsk              => undef
})->get_column('copy_number')->sum;

$counts{'intronic-coding-norepeat'} = $reads_rs->search({
	coding_transcript => {'!=', undef},
	exon              => undef,
	rmsk              => undef
})->get_column('copy_number')->sum;

$counts{'exonic-coding-norepeat'} = $reads_rs->search({
	coding_transcript => {'!=', undef},
	exon              => {'!=', undef},
	rmsk              => undef
})->get_column('copy_number')->sum;

$counts{'utr5-exonic-coding-norepeat'} = $reads_rs->search({
	coding_transcript => {'!=', undef},
	exon              => {'!=', undef},
	utr5              => {'!=', undef},
	rmsk              => undef
})->get_column('copy_number')->sum;

$counts{'cds-exonic-coding-norepeat'} = $reads_rs->search({
	coding_transcript => {'!=', undef},
	exon              => {'!=', undef},
	cds              => {'!=', undef},
	rmsk              => undef
})->get_column('copy_number')->sum;

$counts{'utr3-exonic-coding-norepeat'} = $reads_rs->search({
	coding_transcript => {'!=', undef},
	exon              => {'!=', undef},
	utr3              => {'!=', undef},
	rmsk              => undef
})->get_column('copy_number')->sum;


#################################
warn "Creating output path\n" if $verbose;
my (undef, $directory, undef) = File::Spec->splitpath($o_file); make_path($directory);


##############################################
warn "Printing results\n" if $verbose;
open (my $OUT, '>', $o_file);
print $OUT 
	join("\t", 'category',                     'count',                                'total')."\n".
	
	join("\t", 'Repeat',                       $counts{'repeats'},                     $counts{'total'})."\n".
	join("\t", 'Intergenic (-repeat)',         $counts{'intergenic'},                  $counts{'total'})."\n".
	join("\t", 'Genic',                        $counts{'genic'},                       $counts{'total'})."\n".
	join("\t", 'Intronic',                     $counts{'intronic'},                    $counts{'total'})."\n".
	join("\t", 'Exonic',                       $counts{'exonic'},                      $counts{'total'})."\n".
	join("\t", 'Genic (-repeat)',              $counts{'genic-norepeat'},              $counts{'total'})."\n".
	join("\t", 'Intronic (-repeat)',           $counts{'intronic-norepeat'},           $counts{'total'})."\n".
	join("\t", 'Exonic (-repeat)',             $counts{'exonic-norepeat'},             $counts{'total'})."\n".
	join("\t", 'Genic (+code -repeat)',        $counts{'genic-coding-norepeat'},       $counts{'total'})."\n".
	join("\t", 'Intronic (+code -repeat)',     $counts{'intronic-coding-norepeat'},    $counts{'total'})."\n".
	join("\t", 'Exonic (+code -repeat)',       $counts{'exonic-coding-norepeat'},      $counts{'total'})."\n".
	join("\t", '5UTR (+exonic +code -repeat)', $counts{'utr5-exonic-coding-norepeat'}, $counts{'total'})."\n".
	join("\t", 'CDS (+exonic +code -repeat)',  $counts{'cds-exonic-coding-norepeat'},  $counts{'total'})."\n".
	join("\t", '3UTR (+exonic +code -repeat)', $counts{'utr3-exonic-coding-norepeat'}, $counts{'total'})."\n";
close $OUT;


##############################################
# Subroutines used
##############################################
sub check_options_and_arguments {
	
	pod2usage(-verbose => 1, -message => "$0: Driver for database connection is required.\n") if !$driver;
	pod2usage(-verbose => 1, -message => "$0: Database name or path is required.\n") if !$database;
	pod2usage(-verbose => 1, -message => "$0: Database table is required.\n") if !$table;
	
	pod2usage(-verbose => 1, -message => "$0: Output file is required.\n") if !$o_file;
}


sub read_collection {
	my ($type, $file, $driver, $database, $table, $p_records_class, $host, $user, $pass) = @_;
	
	return read_collection_from_file($file, $type) if $type =~ /^BED$/;
	return read_collection_from_database($driver, $database, $table, $p_records_class, $host, $user, $pass) if $type =~ /^DBIC$/;
}


sub read_collection_from_file {
	my ($file, $type) = @_;
	
	return GenOO::RegionCollection::Factory->create($type, {
		file => $file
	})->read_collection;
}


sub read_collection_from_database {
	my ($driver, $database, $table, $p_records_class, $host, $user, $pass) = @_;
	
	return GenOO::RegionCollection::Factory->create('DBIC', {
		driver        => $driver,
		host          => $host,
		database      => $database,
		user          => $user,
		password      => $pass,
		table         => $table,
		records_class => $p_records_class,
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