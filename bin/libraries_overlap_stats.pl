#!/usr/bin/env perl

=head1 NAME

libraries_overlap_stats.pl

=head1 SYNOPSIS

libraries_overlap_stats.pl [options/parameters]

Measure the number of records of a library A that overlap those of one or more reference libraries B1, B2, B3, ...

    Input options for primary library.
        -p_type <Str>          input type (eg. DBIC, BED).
        -p_file <Str>          input file. Only works if p_type specifies a file type.
        -p_driver <Str>        driver for database connection (eg. mysql, SQLite). Only works if 
                               p_type is DBIC.
        -p_database <Str>      database name or path to database file for file based databases (eg. SQLite). Only works if p_type is DBIC.
        -p_table <Str>         database table. Only works if p_type is DBIC.
        -p_host <Str>          hostname for database connection. Only works if p_type is DBIC.
        -p_user <Str>          username for database connection. Only works if p_type is DBIC.
        -p_password <Str>      password for database connection. Only works if p_type is DBIC.
        -p_records_class <Str> type of records stored in database (Default:
                               GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3).

    Input options for reference library.
        -r_type <Str>          input type (eg. DBIC, BED).
        -r_file <Str>          input file. Only works if r_type specifies a file type. If used more
                               than once, reference libraries are merged.
        -r_driver <Str>        driver for database connection (eg. mysql, SQLite). Only works if 
                               r_type is DBIC.
        -r_database <Str>      database name or path to database file for file based databases
                               (eg. SQLite). Only works if r_type is DBIC.
        -r_table <Str>         database table. Only works if r_type is DBIC. If used more
                               than once, reference libraries are merged.
        -r_host <Str>          hostname for database connection. Only works if r_type is DBIC.
        -r_user <Str>          username for database connection. Only works if r_type is DBIC.
        -r_password <Str>      password for database connection. Only works if r_type is DBIC.
        -r_records_class <Str> type of records stored in database (Default:
                               GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3).

    Other input.
        -rname_sizes <Str>     file with sizes for reference alignment sequences (rnames). Must be tab
                               delimited (chromosome\tsize) with one line per rname.

    Output.
        -o_file <Str>          filename for output file. If path does not exist it will be created.
    
    Input Filters (only for DBIC input type).
        -p_filter <Filter>     filter primary collection. Option can be given multiple times. 
        -r_filter <Filter>     filter reference collection. Option can be given multiple times.
                               Syntax: column_name="pattern"
                                 e.g. -p_filter deletion="def" -p_filter rmsk="undef" to keep only reads with deletions and not repeat masked.
                                 e.g. -r_filter query_length=">31" -r_filter query_length="<=50" to keep reads longer than 31 and shorter or equal to 50.
                               Supported operators: ">", ">=", "<", "<=", "=", "!=","def", "undef"

    Other options.
        -v                     verbosity. If used progress lines are printed.
        -h                     print help message
        -man                   show man page


=head1 DESCRIPTION

Measure the number of records of a library A that overlap those of one or more reference libraries B1, B2, B3, ...
If more than one reference libraries are given then they are merged into a single one and the overlap is calculated afterwards.

=cut


##############################################
# Import external libraries
use Modern::Perl;
use autodie;
use Getopt::Long;
use Pod::Usage;
use File::Path qw(make_path);
use File::Spec;
use PDL; $PDL::BIGPDL = 0; $PDL::BIGPDL++; # enable huge pdls


##############################################
# Import GenOO
use GenOO::RegionCollection::Factory;


##############################################
# Defaults and arguments
my $p_type = 'DBIC';
my $r_type = 'DBIC';
my $p_records_class = 'GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3';
my $r_records_class = 'GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3';

GetOptions(
# Input options for primary library.
	'p_type=s'           => \$p_type,
	'p_file=s'           => \my $p_file,
	'p_driver=s'         => \my $p_driver,
	'p_host=s'           => \my $p_host,
	'p_database=s'       => \my $p_database,
	'p_table=s'          => \my $p_table,
	'p_user=s'           => \my $p_user,
	'p_password=s'       => \my $p_pass,
	'p_records_class=s'  => \$p_records_class,
# Input options for reference library.
	'r_type=s'           => \$r_type,
	'r_file=s'           => \my @r_files,
	'r_driver=s'         => \my $r_driver,
	'r_host=s'           => \my $r_host,
	'r_database=s'       => \my $r_database,
	'r_table=s'          => \my @r_tables,
	'r_user=s'           => \my $r_user,
	'r_password=s'       => \my $r_pass,
	'r_records_class=s'  => \$r_records_class,
# Other input
	'rname_sizes=s'      => \my $rname_size_file,
# Output
	'o_file=s'           => \my $o_file,
# Input Filters (only for DBIC input type)
	'p_filter=s'         => \my @p_filters, # eg. -p_filter deletion="def" -p_filter score="!=100"
	'r_filter=s'         => \my @r_filters, # eg. -r_filter rmsk="undef" -r_filter alignment_length=">31"
# Other options
	'h'                  => \my $help,
	'man'                => \my $man,
	'v'                  => \my $verbose,
) or pod2usage({-verbose => 0});

pod2usage(-verbose => 1)  if $help;
pod2usage(-verbose => 2)  if $man;


##############################################
warn "Reading sizes for reference alignment sequences\n" if $verbose;
my %rname_sizes = read_rname_sizes($rname_size_file);


##############################################
warn "Creating reads collection for primary sample\n" if $verbose;
my $p_reads_collection = read_collection($p_type, $p_file, $p_driver, $p_database, $p_table, $p_records_class, $p_host, $p_user, $p_pass);
apply_simple_filters($p_reads_collection, \@p_filters) if $p_type eq 'DBIC';
my @rnames = $p_reads_collection->rnames_for_all_strands();


##############################################
warn "Creating collection for reference sample\n" if $verbose;
my @r_reads_collections = map {read_collection($r_type, $_, $r_driver, $r_database, $_, $r_records_class, $r_host, $r_user, $r_pass)} (@r_tables, @r_files);
map {apply_simple_filters($_, \@r_filters)} @r_reads_collections if $r_type eq 'DBIC';


##############################################
warn "Measuring the overlap of the primary library with the reference\n" if $verbose;
my $total_copy_number = 0;       # The total copy number of primary records
my $total_records = 0;           # The total number of primary records
my $overlapping_copy_number = 0; # The total copy number of primary records that overlap the reference
my $overlapping_records = 0;     # The total number of primary records that overlap the reference
foreach my $rname (@rnames) {
	warn " Annotating $rname with reference records\n" if $verbose;
	my $rname_size = $rname_sizes{$rname};
	my $pdl_plus   = zeros(byte, $rname_size);
	my $pdl_minus  = zeros(byte, $rname_size);
	foreach my $r_reads_collection (@r_reads_collections) {
		$r_reads_collection->foreach_record_on_rname_do($rname, sub {
			my ($r_record) = @_;
			
			my $coords = [$r_record->start, $r_record->stop];
			$pdl_plus->slice([$r_record->start, $r_record->stop])  .= 1 if $r_record->strand == 1;
			$pdl_minus->slice([$r_record->start, $r_record->stop]) .= 1 if $r_record->strand == -1;
			
			return 0;
		});
	}
	
	warn " Parsing primary records on $rname and checking for overlap with reference\n" if $verbose;
	$p_reads_collection->foreach_record_on_rname_do($rname, sub {
		my ($p_record) = @_;
		
		my $overlap = 0;
		my $coords = [$p_record->start, $p_record->stop];
		$overlap = sum($pdl_plus->slice($coords)) if $p_record->strand == 1;
		$overlap = sum($pdl_minus->slice($coords)) if $p_record->strand == -1;
		
		if ($overlap) {
			$overlapping_copy_number += $p_record->copy_number;
			$overlapping_records += 1;
		}
		
		$total_copy_number += $p_record->copy_number;
		$total_records += 1;
		
		return 0;
	});
}


#################################
warn "Creating output path\n" if $verbose;
my ($volume, $directory, $file) = File::Spec->splitpath($o_file); make_path($directory);


##############################################
warn "Printing results\n" if $verbose;
open(my $OUT, '>', $o_file);
say $OUT join("\t", 'total_records', 'total_copy_number', 'overlapping_records', 'overlapping_copy_number', 'overlapping_records_percent', 'overlapping_copy_number_percent');
say $OUT join("\t", $total_records, $total_copy_number, $overlapping_records, $overlapping_copy_number, ($overlapping_records / $total_records) * 100, ($overlapping_copy_number / $total_copy_number) * 100);
close $OUT;


###########################################
# Subroutines used
###########################################
sub read_collection {
	my ($type, $file, $driver, $database, $table, $p_records_class, $host, $user, $pass) = @_;
	
	return read_collection_from_file($file) if $type =~ /^BED$/;
	return read_collection_from_database($driver, $database, $table, $p_records_class, $host, $user, $pass) if $type =~ /^DBIC$/;
	
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
	my ($driver, $database, $table, $p_records_class, $host, $user, $pass) = @_;
	
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
		records_class => $p_records_class,
	})->read_collection;
}

sub read_rname_sizes {
	my ($rname_size_file) = @_;
	
	pod2usage(-verbose => 1, -message => "$0: File with sizes for reference alignment sequences is required.\n") if !$rname_size_file;
	
	my %rname_size;
	open (my $CHRSIZE, '<', $rname_size_file);
	while (my $line = <$CHRSIZE>) {
		chomp $line;
		my ($chr, $size) = split(/\t/, $line);
		$rname_size{$chr} = $size;
	}
	close $CHRSIZE;
	return %rname_size;
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
