=head1 NAME

CLIPSeqTools::Role::Option::ReferenceLibrary - Role to enable reading reference libraries with reads from the command line

=head1 SYNOPSIS

Role to enable reading reference libraries with reads from the command line

  Defines options.
      -r_type <Str>            input type for reference library (eg. DBIC, BED).
      -r_file <Str>            input file for reference library. Only works if type specifies a file type.
      -r_driver <Str>          driver for database connection  for reference library(eg. mysql, SQLite).
      -r_database <Str>        database name or path for reference library (eg. SQLite).
      -r_table <Str>           database table for reference library.
      -r_host <Str>            hostname for database connection for reference library.
      -r_user <Str>            username for database connection for reference library.
      -r_password <Str>        password for database connection for reference library.
      -r_records_class <Str>   type of records stored in database  for reference library (Default: GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3).
      -r_filter <Filter>       filter library. Option can be given multiple times.
                               Syntax: column_name="pattern"
                                 e.g. -filter deletion="def" -filter rmsk="undef" to keep reads with deletions and not repeat masked.
                                 e.g. -filter query_length=">31" -filter query_length="<=50" to keep reads longer than 31 and shorter or   equal to 50.
                               Supported operators: >, >=, <, <=, =, !=, def, undef.

  Provides attributes.
      r_reads_collection      the collections of reads that are read from the source specified by the options above

=cut


package CLIPSeqTools::Role::Option::ReferenceLibrary;


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use MooseX::App::Role;


#######################################################################
########################   Load GenOO modules   #######################
#######################################################################
use GenOO::RegionCollection::Factory;


#######################################################################
#######################   Command line options   ######################
#######################################################################
option 'r_type' => (
	is            => 'rw',
	isa           => 'Str',
	default       => 'DBIC',
	documentation => 'input type (eg. DBIC, BED, SAM).',
	cmd_tags        => ['Reference library'],
);

option 'r_file' => (
	is            => 'rw',
	isa           => 'Str',
	documentation => 'input file. Only if r_type is a file type.',
	cmd_tags        => ['Reference library'],
);

option 'r_driver' => (
	is            => 'rw',
	isa           => 'Str',
	default       => 'SQLite',
	documentation => 'driver for database connection (eg. mysql, SQLite).',
	cmd_tags        => ['Reference library'],
);

option 'r_database' => (
	is            => 'rw',
	isa           => 'Str',
	documentation => 'database name or path.',
	cmd_tags        => ['Reference library'],
);

option 'r_table' => (
	is            => 'rw',
	isa           => 'Str',
	documentation => 'database table.',
	cmd_tags        => ['Reference library'],
);

option 'r_host' => (
	is            => 'rw',
	isa           => 'Str',
	documentation => 'hostname for database connection.',
	cmd_tags        => ['Reference library'],
);

option 'r_user' => (
	is            => 'rw',
	isa           => 'Str',
	documentation => 'username for database connection.',
	cmd_tags        => ['Reference library'],
);

option 'r_password' => (
	is            => 'rw',
	isa           => 'Str',
	documentation => 'password for database connection.',
	cmd_tags        => ['Reference library'],
);

option 'r_records_class' => (
	is            => 'rw',
	isa           => 'Str',
	default       => 'GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3',
	documentation => 'type of records stored in database.',
	cmd_tags        => ['Reference library'],
);

option 'r_filter' => (
	is            => 'rw',
	isa           => 'ArrayRef',
	default       => sub { [] },
	documentation => 'filter reference library. Option can be given multiple times. '.
                     'Syntax: column_name="pattern" '.
                     'e.g. -r_filter deletion="def" -r_filter rmsk="undef" -r_filter query_length=">31" '.
                     'to keep reads with deletions AND not repeats AND longer than 31. '.
                     'Supported operators: >, >=, <, <=, =, !=, def, undef.',
    cmd_tags        => ['Reference library'],
);


#######################################################################
######################   Interface Attributes   #######################
#######################################################################
has 'r_reads_collection' => (
	traits    => [ 'NoGetopt' ],
	is        => 'rw',
	builder   => '_build_reference_collection',
	lazy      => 1,
);


#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {
	my ($self) = @_;
	
	if ($self->r_type eq 'DBIC') {
		$self->usage_error('Driver for database connection is required') if !$self->r_driver;
		$self->usage_error('Database name or path is required') if !$self->r_database;
		$self->usage_error('Database table is required') if !$self->r_table;
	}
	elsif ($self->r_type eq 'BED' or $self->r_type eq 'SAM') {
		$self->usage_error('File is required') if !$self->r_file;
	}
	else {
		$self->usage_error('Unknown or no input type specified');
	}
}


#######################################################################
#########################   Private Methods   #########################
#######################################################################
sub _build_reference_collection {
	my ($self) = @_;
	
	if ($self->r_type =~ /^DBIC$/) {
		my $collection = $self->_build_reference_collection_from_database;
		_apply_simple_filters_on_reference_collection($self->filter, $collection);
		return $collection;
	}
	elsif ($self->r_type =~ /^(BED|SAM)$/) {
		return $self->_build_reference_collection_from_file;
	}
}

sub _build_reference_collection_from_file {
	my ($self) = @_;
	
	return GenOO::RegionCollection::Factory->create($self->r_type, {
		file => $self->r_file
	})->read_collection;
}

sub _build_reference_collection_from_database {
	my ($self) = @_;
	
	return GenOO::RegionCollection::Factory->create('DBIC', {
		driver        => $self->r_driver,
		host          => $self->r_host,
		database      => $self->r_database,
		user          => $self->r_user,
		password      => $self->r_password,
		table         => $self->r_table,
		records_class => $self->r_records_class,
	})->read_collection;
}

sub _apply_simple_filters_on_reference_collection {
	my ($filters, $collection) = @_;
	
	my @elements = @{$filters};
	foreach my $element (@elements) {
		$element =~ /^(.+?)=(.+?)$/;
		my $col_name = $1;
		my $filter   = $2;
		$collection->simple_filter($col_name, $filter);
	}
}


1;