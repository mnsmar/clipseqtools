#!/usr/bin/env perl

=head1 NAME

annotate_db_sample_with_transcript_info.pl

=head1 SYNOPSIS

annotate_db_sample_with_transcript_info.pl [options/parameters]

Annotate a database table that contains alignments with gene transcript info. Add columns named "transcript", "exon", "coding_transcript", "utr5", "cds", "utr3" which will be null if the alignment is contained in a corresponding region and not null otherwise.

  Input options for library.
      -driver <Str>          driver for database connection (eg. mysql, SQLite).
      -database <Str>        database name or path to database file for file based databases.
      -table <Str>           database table.
      -host <Str>            hostname for database connection.
      -user <Str>            username for database connection.
      -password <Str>        password for database connection.
      -records_class <Str>   type of records stored in database (Default: GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3).

  Other Input.
      -gtf <Str>             GTF file for transcripts.

  Flags.
      -drop                  flag that if set the program will attempt to drop the column if it already exists (not working for SQlite).

  Other options.
      -v                     verbosity. If used progress lines are printed.
      -h                     print help message
      -man                   show man page


=head1 DESCRIPTION

Annotate a database table that contains alignments with gene transcript info. Add columns named "transcript", "exon", "coding_transcript", "utr5", "cds", "utr3" which will be null if the alignment is contained in a corresponding region and not null otherwise.

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
use GenOO::TranscriptCollection::Factory;


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
	'gtf=s'           => \my $transcript_gtf_file,
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


#################################
if ($drop_column) {
	warn "Droping columns transcript, exon, coding_transcript, utr5, cds, utr3 for table $table\n" if $verbose;
	try {
		$reads_collection->schema->storage->dbh_do( sub {
			my ($storage, $databaseh, @cols) = @_;
			$databaseh->do( "ALTER TABLE $table DROP COLUMN transcript" );
			$databaseh->do( "ALTER TABLE $table DROP COLUMN exon" );
			$databaseh->do( "ALTER TABLE $table DROP COLUMN coding_transcript" );
			$databaseh->do( "ALTER TABLE $table DROP COLUMN utr5" );
			$databaseh->do( "ALTER TABLE $table DROP COLUMN cds" );
			$databaseh->do( "ALTER TABLE $table DROP COLUMN utr3" );
		});
	};
}

try {
	warn "Adding column transcript, exon, coding_transcript, utr5, cds, utr3 for table $table\n" if $verbose;
	$reads_collection->schema->storage->dbh_do( sub {
		my ($storage, $databaseh, @cols) = @_;
		$databaseh->do( "ALTER TABLE $table ADD COLUMN transcript INT(1)" );
		$databaseh->do( "ALTER TABLE $table ADD COLUMN coding_transcript INT(1)" );
		$databaseh->do( "ALTER TABLE $table ADD COLUMN exon INT(1)" );
		$databaseh->do( "ALTER TABLE $table ADD COLUMN utr5 INT(1)" );
		$databaseh->do( "ALTER TABLE $table ADD COLUMN cds INT(1)" );
		$databaseh->do( "ALTER TABLE $table ADD COLUMN utr3 INT(1)" );
	});
} catch {
	die "Column creation failed. Maybe some columns already exist.\n".
	    "Caught error: $_";
};


##############################################
warn "Creating transcript collection\n" if $verbose;
my $transcript_collection = GenOO::TranscriptCollection::Factory->create('GTF', {
	file => $transcript_gtf_file
})->read_collection;


##############################################
warn "Looping on transcripts to annotate records in table $table\n";
my $counter = 0;
$reads_collection->schema->txn_do(sub {
	$transcript_collection->foreach_record_do( sub {
		my ($transcript) = @_;
		
		my $transcript_reads_rs = $reads_rs->search({
			strand => $transcript->strand,
			rname  => $transcript->rname,
			start  => { '-between' => [$transcript->start, $transcript->stop] },
			stop   => { '-between' => [$transcript->start, $transcript->stop] },
		});
		
		$transcript_reads_rs->update({transcript => 1});
		
		foreach my $exon (@{$transcript->exons}) {
			my $exon_reads_rs = $transcript_reads_rs->search([
				start => { '-between' => [$exon->start, $exon->stop] },
				stop  => { '-between' => [$exon->start, $exon->stop] },
			]);
			
			$exon_reads_rs->update({exon => 1});
		}
		
		if ($transcript->is_coding) {
			foreach my $part_type ('utr5', 'cds', 'utr3') {
				my $part = $transcript->$part_type() or next;
				my $part_reads_rs = $transcript_reads_rs->search([
					start => { '-between' => [$part->start, $part->stop] },
					stop  => { '-between' => [$part->start, $part->stop] },
				]);
				
				$part_reads_rs->update({$part_type => 1});
			}
			
			$transcript_reads_rs->update({coding_transcript => 1});
		}
		
		$counter++;
		if ($counter % 1000 == 0) {
			warn "Parsed records: $counter/".$transcript_collection->records_count." in ".(time - $time)."sec\n" if $verbose;
		}
	});
});


warn "Elapsed time: ".((time-$time)/60)." min\n" if $verbose;


##############################################
# Subroutines used
##############################################
sub check_options_and_arguments {
	
	pod2usage(-verbose => 1, -message => "$0: Driver for database connection is required.\n") if !$driver;
	pod2usage(-verbose => 1, -message => "$0: Database name or path is required.\n") if !$database;
	pod2usage(-verbose => 1, -message => "$0: Database table is required.\n") if !$table;
	
	pod2usage(-verbose => 1, -message => "$0: GTF file with transcripts is required.\n") if !$transcript_gtf_file;
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


