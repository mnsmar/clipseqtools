#!/usr/bin/env perl

=head1 NAME

annotate_db_sample_with_rmsk.pl

=head1 SYNOPSIS

annotate_db_sample_with_rmsk.pl [options/parameters]

Annotate a database table that contains alignments with Repeat Masker info. Add a column named rmsk which will be null if the alignment is not contained in a repeat region and not null otherwise..

  Input options for library.
      -driver <Str>          driver for database connection (eg. mysql, SQLite).
      -database <Str>        database name or path to database file for file based databases.
      -table <Str>           database table.
      -host <Str>            hostname for database connection.
      -user <Str>            username for database connection.
      -password <Str>        password for database connection.
      -records_class <Str>   type of records stored in database (Default: GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3).

  Other Input.
      -rmsk_file <Str>       BED file with the repeat masker regions.

  Flags.
      -drop                  flag that if set the program will attempt to drop the column if it already exists (not working for SQlite).

  Other options.
      -v                     verbosity. If used progress lines are printed.
      -h                     print help message
      -man                   show man page


=head1 DESCRIPTION

Annotate a database table that contains alignments with Repeat Masker info. Add a column named rmsk which will be null if the alignment is not contained in a repeat region and not null otherwise..

=cut


##############################################
# Import external libraries
use Modern::Perl;
use autodie;
use Getopt::Long;
use Pod::Usage;
use Try::Tiny;


##############################################
# Import GenOO
use GenOO::RegionCollection::Factory;
use GenOO::Data::File::BED;


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
# Outher Input
	'rmsk_file=s'     => \my $rmsk_file,
# Flags
	'drop_column'     => \my $drop_column,
# Other options
	'h'               => \my $help,
	'man'             => \my $man,
	'v'               => \my $verbose,
) or pod2usage({-verbose => 0});

pod2usage(-verbose => 1)  if $help;
pod2usage(-verbose => 2)  if $man;
my $time = time;

##############################################
warn "Checking the input\n" if $verbose;
check_options_and_arguments();


##############################################
warn "Creating reads collection\n" if $verbose;
my $reads_collection = read_collection('DBIC', undef, $driver, $database, $table, $records_class, $host, $user, $pass);


##############################################
warn "Preparing collection resultset\n" if $verbose;
my $reads_rs = $reads_collection->resultset;


##############################################
if ($drop_column) {
	warn "Droping column rmsk for table $table\n" if $verbose;
	try {
		$reads_collection->schema->storage->dbh_do( sub {
			my ($storage, $databaseh, @cols) = @_;
			$databaseh->do( "ALTER TABLE $table DROP COLUMN rmsk" );
		});
	};
}

try {
	warn "Adding column rmsk for table $table\n" if $verbose;
	$reads_collection->schema->storage->dbh_do( sub {
		my ($storage, $databaseh, @cols) = @_;
		$databaseh->do( "ALTER TABLE $table ADD COLUMN rmsk INT(1)" );
	});
};


##############################################
warn "Opening the BED file\n" if $verbose;
my $bed = GenOO::Data::File::BED->new(file => $rmsk_file);


##############################################
warn "Parsing BED to annotate records in table $table\n" if $verbose;
my $continue = 1;
while ($continue) {
	$continue = $reads_collection->schema->txn_do(sub {
		while (my $record = $bed->next_record) {
			my $overlapping_reads_rs = $reads_rs->search({
				rname => $record->rname,
				start => { '-between' => [$record->start, $record->stop] },
				stop  => { '-between' => [$record->start, $record->stop] },
				rmsk  => undef,
			});
			
			$overlapping_reads_rs->update({rmsk => 1});
			
			if ($bed->records_read_count % 10000 == 0) {
				warn "Parsed records: ".$bed->records_read_count."/".(time - $time)."sec\n" if $verbose;
				return 1;
			}
		}
		
		return 0;
	});
}

warn "Elapsed time: ".((time-$time)/60)." min\n" if $verbose;


##############################################
# Subroutines used
##############################################
sub check_options_and_arguments {
	
	pod2usage(-verbose => 1, -message => "$0: Driver for database connection is required.\n") if !$driver;
	pod2usage(-verbose => 1, -message => "$0: Database name or path is required.\n") if !$database;
	pod2usage(-verbose => 1, -message => "$0: Database table is required.\n") if !$table;
	
	pod2usage(-verbose => 1, -message => "$0: BED file with repeats is required.\n") if !$rmsk_file;
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
