#!/usr/bin/env perl

=head1 NAME

annotate_db_sample_with_deletion.pl

=head1 SYNOPSIS

annotate_db_sample_with_deletion.pl [options/parameters]

Annotate a database table that contains alignments with Repeat Masker info. Add a column named deletion which will be null if the alignment is not contained in a repeat region and not null otherwise..

  Input options for library.
      -driver <Str>          driver for database connection (eg. mysql, SQLite).
      -database <Str>        database name or path to database file for file based databases.
      -table <Str>           database table.
      -host <Str>            hostname for database connection.
      -user <Str>            username for database connection.
      -password <Str>        password for database connection.
      -records_class <Str>   type of records stored in database (Default: GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3).

  Flags.
      -drop                  flag that if set the program will attempt to drop the column if it already exists (not working for SQlite).

  Other options.
      -v                     verbosity. If used progress lines are printed.
      -h                     print help message
      -man                   show man page


=head1 DESCRIPTION

Annotate a database table that contains alignments with Repeat Masker info. Add a column named deletion which will be null if the alignment is not contained in a repeat region and not null otherwise..

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
# $reads_collection->schema->storage->debug(1);

##############################################
if ($drop_column) {
	warn "Droping column deletion for table $table\n" if $verbose;
	try {
		$reads_collection->schema->storage->dbh_do( sub {
			my ($storage, $dbh, @cols) = @_;
			$dbh->do( "ALTER TABLE $table DROP COLUMN deletion" );
		});
	};
}

try {
	warn "Adding column deletion for table $table\n" if $verbose;
	$reads_collection->schema->storage->dbh_do( sub {
		my ($storage, $dbh, @cols) = @_;
		$dbh->do( "ALTER TABLE $table ADD COLUMN deletion INT(1)" );
	});
};

$reads_collection->resultset->result_source->add_column('deletion' => {
	data_type => 'integer',
	extra => { unsigned => 1 },
	is_nullable => 1,
	is_numeric => 1
});

##############################################
warn "Annotating records in table $table\n" if $verbose;
$reads_collection->foreach_record_do( sub {
my ($record) = @_;
	if ($record->deletion_count > 0){
		$record->{"_column_data"}->{"deletion"} = 1;
		$record->make_column_dirty('deletion');
		$record->update();
	}
	return 0;
});
warn "Elapsed time: ".((time-$time)/60)." min\n" if $verbose;


##############################################
# Subroutines used
##############################################
sub check_options_and_arguments {
	
	pod2usage(-verbose => 1, -message => "$0: Driver for database connection is required.\n") if !$driver;
	pod2usage(-verbose => 1, -message => "$0: Database name or path is required.\n") if !$database;
	pod2usage(-verbose => 1, -message => "$0: Database table is required.\n") if !$table;
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
