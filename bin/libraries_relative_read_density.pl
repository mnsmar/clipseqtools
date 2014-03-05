#!/usr/bin/env perl

=head1 NAME

libraries_relative_read_density.pl

=head1 SYNOPSIS

libraries_relative_read_density.pl [options/parameters]

For a library A and a reference library B, measure the density of A reads around the middle position of B reads.

    Input options for primary library.
        -p_type <Str>          input type (eg. DBIC, BED).
        -p_file <Str>          input file. Only works if p_type specifies a file type.
        -p_driver <Str>        driver for database connection (eg. mysql, SQLite). Only works if p_type is DBIC.
        -p_database <Str>      database name or path to database file for file based databases (eg. SQLite). Only works if p_type is DBIC.
        -p_table <Str>         database table. Only works if p_type is DBIC.
        -p_host <Str>          hostname for database connection. Only works if p_type is DBIC.
        -p_user <Str>          username for database connection. Only works if p_type is DBIC.
        -p_password <Str>      password for database connection. Only works if p_type is DBIC.
        -p_records_class <Str> type of records stored in database (Default: GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3).

    Input options for reference library.
        -r_type <Str>          input type (eg. DBIC, BED).
        -r_file <Str>          input file. Only works if r_type specifies a file type.
        -r_driver <Str>        driver for database connection (eg. mysql, SQLite). Only works if r_type is DBIC.
        -r_database <Str>      database name or path to database file for file based databases (eg. SQLite). Only works if r_type is DBIC.
        -r_table <Str>         database table. Only works if r_type is DBIC.
        -r_host <Str>          hostname for database connection. Only works if r_type is DBIC.
        -r_user <Str>          username for database connection. Only works if r_type is DBIC.
        -r_password <Str>      password for database connection. Only works if r_type is DBIC.
        -r_records_class <Str> type of records stored in database (Default: GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3).

    Other input.
        -rname_sizes <Str>     file with sizes for reference alignment sequences (rnames). Must be tab delimited (chromosome\tsize) with one line per rname

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
        -span <Int>            the region around reference records in which density is measured
        -v                     verbosity. If used progress lines are printed.
        -h                     print help message
        -man                   show man page


=head1 DESCRIPTION

For two libraries, a primary and a reference one, measure the density of primary reads around the middle position of the
reference ones.

=cut


##############################################
# Import external libraries
use Modern::Perl;
use autodie;
use Getopt::Long;
use Pod::Usage;
use File::Path qw(make_path);
use File::Spec;
use PDL 2.007; $PDL::BIGPDL = 0; $PDL::BIGPDL++; # enable huge pdls


##############################################
# Import GenOO
use GenOO::RegionCollection::Factory;


##############################################
# Defaults and arguments
my $span = 25;
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
	'r_file=s'           => \my $r_file,
	'r_driver=s'         => \my $r_driver,
	'r_host=s'           => \my $r_host,
	'r_database=s'       => \my $r_database,
	'r_table=s'          => \my $r_table,
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
	'span=i'             => \$span,
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
warn "Creating reads collection for reference sample\n" if $verbose;
my $r_reads_collection = read_collection($r_type, $r_file, $r_driver, $r_database, $r_table, $r_records_class, $r_host, $r_user, $r_pass);
apply_simple_filters($r_reads_collection, \@r_filters) if $r_type eq 'DBIC';


##############################################
warn "Measuring density of primary reads around reference records\n" if $verbose;
my $counts_with_copy_number_sense     = zeros(longlong, 2*$span+1);
my $counts_with_copy_number_antisense = zeros(longlong, 2*$span+1);
my $counts_no_copy_number_sense       = zeros(longlong, 2*$span+1);
my $counts_no_copy_number_antisense   = zeros(longlong, 2*$span+1);
foreach my $rname (@rnames) {
	warn "Annotate $rname with primary records\n" if $verbose;
	my $rname_size = $rname_sizes{$rname};
	my $pdl_plus_with_copy_number  = zeros(long, $rname_size);
	my $pdl_plus_no_copy_number    = zeros(long, $rname_size);
	my $pdl_minus_with_copy_number = zeros(long, $rname_size);
	my $pdl_minus_no_copy_number   = zeros(long, $rname_size);
	$p_reads_collection->foreach_record_on_rname_do($rname, sub {
		my ($p_record) = @_;
		
		my $coords = [$p_record->start, $p_record->stop];
		my $copy_number = $p_record->copy_number;
		my $strand = $p_record->strand;
		
		if ($strand == 1) {
			$pdl_plus_with_copy_number->slice($coords) += $copy_number;
			$pdl_plus_no_copy_number->slice($coords)   += 1;
		}
		elsif ($strand == -1) {
			$pdl_minus_with_copy_number->slice($coords) += $copy_number;
			$pdl_minus_no_copy_number->slice($coords)   += 1;
		}
		
		return 0;
	});
	
	warn "Measuring density around reference records on $rname\n" if $verbose;
	$r_reads_collection->foreach_record_on_rname_do($rname, sub {
		my ($r_record) = @_;
		
		my $ref_pos = $r_record->mid_position;
		my $begin   = $ref_pos - $span;
		my $end     = $ref_pos + $span;
		my $copy_number = $r_record->copy_number;
		my $strand = $r_record->strand;
		
		return 0 if $begin < 0 or $end >= $rname_size;
		
		if ($strand == 1) {
			my $coords = [$begin, $end];
			$counts_with_copy_number_sense     += $pdl_plus_with_copy_number->slice($coords)  * $copy_number;
			$counts_no_copy_number_sense       += $pdl_plus_no_copy_number->slice($coords);
			$counts_with_copy_number_antisense += $pdl_minus_with_copy_number->slice($coords) * $copy_number;
			$counts_no_copy_number_antisense   += $pdl_minus_no_copy_number->slice($coords);
		}
		elsif ($strand == -1) {
			my $coords = [$end, $begin]; #reverse
			$counts_with_copy_number_sense     += $pdl_minus_with_copy_number->slice($coords) * $copy_number;
			$counts_no_copy_number_sense       += $pdl_minus_no_copy_number->slice($coords);
			$counts_with_copy_number_antisense += $pdl_plus_with_copy_number->slice($coords)  * $copy_number;
			$counts_no_copy_number_antisense   += $pdl_plus_no_copy_number->slice($coords);
		}
		
		return 0;
	});
}


##############################################
warn "Creating output path\n" if $verbose;
my ($volume, $directory, $file) = File::Spec->splitpath($o_file); make_path($directory);


##############################################
warn "Printing results\n" if $verbose;
open(my $OUT, '>', $o_file);
say $OUT join("\t", 'relative_position', 'counts_with_copy_number_sense', 'counts_no_copy_number_sense', 'counts_with_copy_number_antisense', 'counts_no_copy_number_antisense');
for (my $distance = 0-$span; $distance<=$span; $distance++) {
	my $idx = $distance + $span;
	say $OUT join("\t", $distance, $counts_with_copy_number_sense->at($idx), $counts_no_copy_number_sense->at($idx), $counts_with_copy_number_antisense->at($idx), $counts_no_copy_number_antisense->at($idx));
}
close $OUT;


##############################################
# Subroutines used
##############################################
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
