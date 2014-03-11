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


package CLIPSeqTools::Role::CollectionFilter;


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
has 'filter' => (
	is            => 'rw',
	isa           => 'ArrayRef',
	traits        => ['Getopt'],
	default       => sub { [] },
	documentation => 'filter library. Option can be given multiple times.'.
                     'Filter syntax: column_name="pattern"'.
                     '  e.g. -filter deletion="def" -filter rmsk="undef" to keep reads with deletions and not repeat masked.'.
                     '  e.g. -filter query_length=">31" -filter query_length="<=50" to keep reads longer than 31 and shorter or equal to 50.'.
                     'Supported operators: ">", ">=", "<", "<=", "=", "!=","def", "undef"',
);


#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {
	my ($self) = @_;
}

sub apply_simple_filters_on_collection {
	my ($self, $collection) = @_;
	
	my @elements = @{$self->filter};
	foreach my $element (@elements) {
		$element =~ /^(.+?)=(.+?)$/;
		my $col_name = $1;
		my $filter   = $2;
		$collection->simple_filter($col_name, $filter);
	}
}


1;