=head1 NAME

CLIPSeqTools::App::Command::genome_coverage - Measure the percent of the genome that is covered by the reads of a library.

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


package CLIPSeqTools::Role::CollectionReader;


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use Moose::Role;


#######################################################################
########################   Load GenOO modules   #######################
#######################################################################
use GenOO::RegionCollection::Factory;


#######################################################################
#######################   Command line options   ######################
#######################################################################
has 'type' => (
	is            => 'rw',
	isa           => 'Str',
	traits        => ['Getopt'],
	default       => 'DBIC',
	documentation => 'input type (eg. DBIC, BED, SAM).',
);

has 'file' => (
	is            => 'rw',
	isa           => 'Str',
	traits        => ['Getopt'],
	documentation => 'input file. Only works if type specifies a file type.',
);

has 'driver' => (
	is            => 'rw',
	isa           => 'Str',
	traits        => ['Getopt'],
	default       => 'SQLite',
	documentation => 'driver for database connection (eg. mysql, SQLite). Only works if type is DBIC.',
);

has 'database' => (
	is            => 'rw',
	isa           => 'Str',
	traits        => ['Getopt'],
	documentation => 'database name or path to database file for file based databases (eg. SQLite). Only works if type is DBIC.',
);

has 'table' => (
	is            => 'rw',
	isa           => 'Str',
	traits        => ['Getopt'],
	documentation => 'database table. Only works if type is DBIC.',
);

has 'host' => (
	is            => 'rw',
	isa           => 'Str',
	traits        => ['Getopt'],
	documentation => 'hostname for database connection. Only works if type is DBIC.',
);

has 'user' => (
	is            => 'rw',
	isa           => 'Str',
	traits        => ['Getopt'],
	documentation => 'input type (eg. DBIC, BED, SAM).',
);

has 'password' => (
	is            => 'rw',
	isa           => 'Str',
	traits        => ['Getopt'],
	documentation => 'password for database connection. Only works if type is DBIC.',
);

has 'records_class' => (
	is            => 'rw',
	isa           => 'Str',
	traits        => ['Getopt'],
	default       => 'GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3',
	documentation => 'type of records stored in database.',
);


#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {
	my ($self) = @_;
	
	if ($self->type eq 'DBIC') {
		$self->usage_error('Driver for database connection is required for type DBIC') if !$self->driver;
		$self->usage_error('Database name or path is required for type DBIC') if !$self->database;
		$self->usage_error('Database table is required for type DBIC') if !$self->table;
	}
	elsif ($self->type eq 'BED' or $self->type eq 'SAM') {
		$self->usage_error('File is required for type '.$self->type) if !$self->file;
	}
	else {
		$self->usage_error('Unknown or no input type specified');
	}
}

sub read_collection {
	my ($self) = @_;
	
	return $self->read_collection_from_file if $self->type =~ /^(BED|SAM)$/;
	return $self->read_collection_from_database if $self->type =~ /^DBIC$/;
}

sub read_collection_from_file {
	my ($self) = @_;
	
	return GenOO::RegionCollection::Factory->create($self->type, {
		file => $self->file
	})->read_collection;
}

sub read_collection_from_database {
	my ($self) = @_;
	
	return GenOO::RegionCollection::Factory->create('DBIC', {
		driver        => $self->driver,
		host          => $self->host,
		database      => $self->database,
		user          => $self->user,
		password      => $self->password,
		table         => $self->table,
		records_class => $self->records_class,
	})->read_collection;
}


1;