#!/usr/bin/env perl

=head1 NAME

genome_coverage.pl

=head1 SYNOPSIS

genome_coverage.pl [options/parameters]

Measure the percent of the genome that is covered by the reads of a library.

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
      -rname_sizes <Str>     file with sizes for reference alignment sequences (rnames). Must be tab
                             delimited (chromosome\tsize) with one line per rname.

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

Measure the percent of the genome that is covered by the reads of a library.

=cut


##############################################
# Import external libraries
use Modern::Perl;
use autodie;
use Getopt::Long;
use Pod::Usage;
use File::Path qw(make_path);
use File::Spec;
use Math::Round;
use PDL;


##############################################
# Import GenOO
use GenOO::RegionCollection::Factory;


##############################################
# Read command options
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
	'rname_sizes=s'   => \my $rname_size_file,
# Output
	'o_file=s'        => \my $o_file,
# Input Filters (only for DBIC input type)
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
warn "Reading sizes for reference alignment sequences\n" if $verbose;
my %rname_sizes = read_rname_sizes($rname_size_file);


##############################################
warn "Creating reads collection\n" if $verbose;
my $reads_collection = read_collection($type, $file, $driver, $database, $table, $records_class, $host, $user, $pass);
apply_simple_filters($reads_collection, \@filters) if $type eq 'DBIC';
my @rnames = $reads_collection->rnames_for_all_strands;


#################################
warn "Creating output path\n" if $verbose;
my (undef, $directory, undef) = File::Spec->splitpath($o_file); make_path($directory);


##############################################
warn "Calculating genome coverage\n" if $verbose;
my $total_genome_coverage = 0;
my $total_genome_length = 0;
open(my $OUT, '>', $o_file);
say $OUT join("\t", 'rname', 'covered_area', 'size', 'percent_covered');
foreach my $rname (@rnames) {
	warn "Working for $rname\n" if $verbose;
	my $pdl = zeros(byte, $rname_sizes{$rname});
	
	$reads_collection->foreach_record_on_rname_do($rname, sub {
		$pdl->slice([$_[0]->start, $_[0]->stop]) .= 1;
		return 0;
	});
	
	my $covered_area = sum($pdl);
	say $OUT join("\t", $rname, $covered_area, $rname_sizes{$rname}, $covered_area/$rname_sizes{$rname}*100);
	
	$total_genome_coverage += $covered_area;
	$total_genome_length += $rname_sizes{$rname};
}
say $OUT join("\t", 'Total', $total_genome_coverage, $total_genome_length, $total_genome_coverage/$total_genome_length*100);
close $OUT;



###########################################
# Subroutines
###########################################
sub check_options_and_arguments {
	
	if ($type eq 'BED') {
		pod2usage(-verbose => 1, -message => "$0: File is required.\n") if !$file;
	}
	elsif ($type eq 'DBIC') {
		pod2usage(-verbose => 1, -message => "$0: Driver for database connection is required.\n") if !$driver;
		pod2usage(-verbose => 1, -message => "$0: Database name or path is required.\n") if !$database;
		pod2usage(-verbose => 1, -message => "$0: Database table is required.\n") if !$table;
	}
	else {
		pod2usage(-verbose => 1, -message => "$0: Unknown or no input type specified.\n");
	}
	
	pod2usage(-verbose => 1, -message => "$0: File with sizes for reference alignment sequences is required.\n") if !$rname_size_file;
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


sub read_rname_sizes {
	my ($rname_size_file) = @_;
	
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
