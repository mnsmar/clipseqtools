#!/usr/bin/env perl

=head1 NAME

load_sam_to_sqlite_database.pl

=head1 SYNOPSIS

load_sam_to_sqlite_database.pl [options/parameters]

Store alignments from a SAM file into and SQlite database. If exists tag XC:i is used as copy number for the record.

  Input options.
      -sam_file <Str>          sam file that will be stored in the database. If not specified STDIN is used.
      -sam_record_class <Str>  type of records stored in the SAM file (Default: GenOOx::Data::File::SAMstar::Record)
      
  Output options.
      -database <Str>        database name or path to database file for file based databases.
      -table <Str>           database table.
      -drop <Str>            flag that if set drops the database table if it already exists.

  Other options.
      -v                     verbosity. If used progress lines are printed.
      -h                     print help message
      -man                   show man page


=head1 DESCRIPTION

Store alignments from a SAM file into and SQlite database. If exists tag XC:i is used as copy number for the record.

=cut


##############################################
# Import external libraries
use Modern::Perl;
use autodie;
use Getopt::Long;
use Pod::Usage;
use File::Temp;
use DBI;


##############################################
# Import GenOO
use GenOO::Data::File::SAM;


##############################################
# Get user input and initialize
my $sam_record_class = 'GenOOx::Data::File::SAMstar::Record';

GetOptions(
# Input options
	'sam_file=s'         => \my $sam_file,
	'sam_record_class=s' => \$sam_record_class,
# Output options
	'database=s'         => \my $database,
	'table=s'            => \my $table,
	'drop'               => \my $drop_table,
# Other options
	'h'                  => \my $help,
	'man'                => \my $man,
	'v'                  => \my $verbose,
) or pod2usage({-verbose => 0});

pod2usage(-verbose => 1)  if $help;
pod2usage(-verbose => 2)  if $man;


##############################################
warn "Checking the input\n" if $verbose;
check_options_and_arguments();


# Load required classes
eval "require $sam_record_class";


##############################################
warn "Connecting to the database\n" if $verbose;
my $dbh = DBI->connect("dbi:SQLite:database=$database") or die "Can't connect to database: $DBI::errstr\n";


##############################################
if ($drop_table) {
	warn "Dropping table $table\n" if $verbose;
	$dbh->do( qq{DROP TABLE IF EXISTS $table} );
}


##############################################
warn "Creating table $table\n" if $verbose;
{
	local $dbh->{PrintError} = 0; #temporarily suppress the warning in case table already exists
	
	$dbh->do(
		'CREATE TABLE '.$table.' ('.
			'id INTEGER PRIMARY KEY AUTOINCREMENT,'.
			'strand INT(1) NOT NULL,'.
			'rname VARCHAR(250) NOT NULL,'.
			'start UNSIGNED INT(10) NOT NULL,'.
			'stop UNSIGNED INT(10) NOT NULL,'.
			'copy_number UNSIGNED INT(6) NOT NULL DEFAULT 1,'.
			'sequence VARCHAR(250) NOT NULL,'.
			'cigar VARCHAR(250) NOT NULL,'.
			'mdz VARCHAR(250),'.
			'number_of_mappings UNSIGNED INT(5),'.
			'query_length UNSIGNED INT(4) NOT NULL,'.
			'alignment_length UNSIGNED INT(5) NOT NULL'.
		');'
	);
	
	if ($dbh->err) {
		die "Error: ".$dbh->errstr."\n";
	}
}


##############################################
warn "Opening the SAM file\n" if $verbose;
my $sam = GenOO::Data::File::SAM->new(
	file          => $sam_file,
	records_class => $sam_record_class,
);


##############################################
warn "Loading data to table $table\n" if $verbose;
$dbh->begin_work;
my $insert_statement = $dbh->prepare(qq{INSERT INTO $table (id, strand, rname, start, stop, copy_number, sequence, cigar, mdz, number_of_mappings, query_length, alignment_length) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)});
while (my $record = $sam->next_record) {
	my $copy_number = $record->copy_number;
	if (defined $record->tag('XC:i')) {
		$copy_number = $record->tag('XC:i');
	}
	
	$insert_statement->execute(undef,$record->strand, $record->rname, $record->start, $record->stop, $copy_number, $record->query_seq, $record->cigar, $record->mdz, $record->number_of_mappings, $record->query_length, $record->alignment_length);
	
	if ($sam->records_read_count % 100000 == 0) {
		$dbh->commit;
		$dbh->begin_work;
	}
}
$dbh->commit;


##############################################
warn "Building index on $table\n" if $verbose;
$dbh->do(qq{CREATE INDEX $table\_loc ON $table (rname, start);});


##############################################
warn "Disconnecting from the database\n" if $verbose;
$dbh->disconnect;


##############################################
# Subroutines used
##############################################
sub check_options_and_arguments {
	
	pod2usage(-verbose => 1, -message => "$0: Database name or path is required.\n") if !$database;
	pod2usage(-verbose => 1, -message => "$0: Database table is required.\n") if !$table;
}
