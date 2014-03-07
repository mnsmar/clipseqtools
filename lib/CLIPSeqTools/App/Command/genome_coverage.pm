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


package CLIPSeqTools::App::Command::genome_coverage;


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use Getopt::Long;
use Pod::Usage;
use File::Path qw(make_path);
use File::Spec;
use Math::Round;
use PDL;


#######################################################################
########################   Load GenOO modules   #######################
#######################################################################
use GenOO::RegionCollection::Factory;


#######################################################################
##################   Declare that class is a command   ################
#######################################################################
use CLIPSeqTools::App -command;


#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub description {
	return 'Measure the percent of the genome that is covered by the reads of a library';
}


sub opt_spec {
	return (
		[],
		['Input options for library'],
		['type=s',          'input type (eg. DBIC, BED)', {
		                        default => 'DBIC'
		                     }],
		['file=s',          'input file. Only works if type specifies a file type'],
		['driver=s',        'driver for database connection (eg. mysql, SQLite). Only works if type is DBIC'],
		['database=s',      'database name or path to database file for file based databases (eg. SQLite). Only works if type is DBIC'],
		['table=s',         'database table. Only works if type is DBIC.'],
		['host=s',          'hostname for database connection. Only works if type is DBIC'],
		['user=s',          'username for database connection. Only works if type is DBIC'],
		['password=s',      'password for database connection. Only works if type is DBIC'],
		['records_class=s', 'type of records stored in database', {
		                        default => 'GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3'
		                    }],
		
		[],
		['Other input'],
		['rname_sizes=s',   'file with sizes for reference alignment sequences (rnames). '.
		                    'Must be tab delimited (chromosome\tsize) with one line per rname.'],
		[],
		['Output'],
		['o_file=s',        'filename for output file. If path does not exist it will be created.'],
		
		[],
		['Input Filters (only for DBIC input type)'],
		['filter=s@',       'filter library. Option can be given multiple times.'.
                            'Filter syntax: column_name="pattern"'.
                            '  e.g. -filter deletion="def" -filter rmsk="undef" to keep reads with deletions and not repeat masked.'.
                            '  e.g. -filter query_length=">31" -filter query_length="<=50" to keep reads longer than 31 and shorter or equal to 50.'.
                            'Supported operators: ">", ">=", "<", "<=", "=", "!=","def", "undef"'],
		
		[],
		['Other options'],
		['verbose|v',       'If used progress lines are printed'],
		['help|h',          'print usage message and exit' ],
	);
}

sub execute {
	my ($self, $opt, $args) = @_;
	
	
	##############################################
	warn "Reading sizes for reference alignment sequences\n" if $opt->verbose;
	my %rname_sizes = read_rname_sizes($opt->rname_sizes);
	
	
	##############################################
	warn "Creating reads collection\n" if $opt->verbose;
	my $reads_collection = read_collection($opt);
	apply_simple_filters($reads_collection, $opt->filter) if $opt->type eq 'DBIC';
	my @rnames = $reads_collection->rnames_for_all_strands;
	
	
	#################################
	warn "Creating output path\n" if $opt->verbose;
	my (undef, $directory, undef) = File::Spec->splitpath($opt->o_file); make_path($directory);
	
	
	##############################################
	warn "Calculating genome coverage\n" if $opt->verbose;
	my $total_genome_coverage = 0;
	my $total_genome_length = 0;
	open(my $OUT, '>', $opt->o_file);
	say $OUT join("\t", 'rname', 'covered_area', 'size', 'percent_covered');
	foreach my $rname (@rnames) {
		warn "Working for $rname\n" if $opt->verbose;
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
}

sub validate_args {
	my ($self, $opt, $args) = @_;
	
	if ( $opt->help ) {
		my ($command) = $self->command_names;
		$self->app->execute_command(
			$self->app->prepare_command("help", $command)
		);
		exit;
    }
	
	if ($opt->type eq 'DBIC') {
		$self->usage_error("Driver for database connection is required for type DBIC") if !$opt->driver;
		$self->usage_error("Database name or path is required for type DBIC") if !$opt->database;
		$self->usage_error("Database table is required for type DBIC") if !$opt->table;
	}
	elsif ($opt->type eq 'BED' or $opt->type eq 'SAM') {
		$self->usage_error("File is required for type ".$opt->type) if !$opt->file;
	}
	else {
		$self->usage_error("Unknown or no input type specified.\n");
	}
	
	$self->usage_error("File with sizes for reference alignment sequences is required") if !$opt->rname_sizes;
	$self->usage_error("Output file is required.\n") if !$opt->o_file;
}



#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub read_collection {
	my ($opt) = @_;
	
	return read_collection_from_file($opt) if $opt->type =~ /^(BED|SAM)$/;
	return read_collection_from_database($opt) if $opt->type =~ /^DBIC$/;
}


sub read_collection_from_file {
	my ($opt) = @_;
	
	return GenOO::RegionCollection::Factory->create($opt->type, {
		file => $opt->file
	})->read_collection;
}


sub read_collection_from_database {
	my ($opt) = @_;
	
	return GenOO::RegionCollection::Factory->create('DBIC', {
		driver        => $opt->driver,
		host          => $opt->host,
		database      => $opt->database,
		user          => $opt->user,
		password      => $opt->password,
		table         => $opt->table,
		records_class => $opt->records_class,
	})->read_collection;
}


sub read_rname_sizes {
	my ($rname_sizes) = @_;
	
	my %rname_size;
	open (my $CHRSIZE, '<', $rname_sizes);
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


1;