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
      -filter <Filter>       filter library. Option can be given multiple times.
                             Filter syntax: column_name="pattern"
                               e.g. -filter deletion="def" -filter rmsk="undef" to keep reads with deletions and not repeat masked.
                               e.g. -filter query_length=">31" -filter query_length="<=50" to keep reads longer than 31 and shorter or   equal to 50.
                             Supported operators: ">", ">=", "<", "<=", "=", "!=","def", "undef"

  Other input.
      -rname_sizes <Str>     file with sizes for reference alignment sequences (rnames). Must be tab
                             delimited (chromosome\tsize) with one line per rname.

  Output.
      -o_prefix <Str>        output path prefix. Script adds an extension to path. If path does not exist it will be created. Default: ./

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
use Moose;
use namespace::autoclean;
use File::Spec;
use PDL::Lite;


#######################################################################
##################   Declare that class is a command   ################
#######################################################################
extends 'MooseX::App::Cmd::Command';


#######################################################################
#######################   Command line options   ######################
#######################################################################
has 'rname_sizes' => (
	is            => 'rw',
	isa           => 'Str',
	traits        => ['Getopt'],
	documentation => 'file with sizes for reference alignment sequences (rnames). '.
	                 'Must be tab delimited (chromosome\tsize) with one line per rname.',
);


#######################################################################
##########################   Consume Roles   ##########################
#######################################################################
with 'CLIPSeqTools::Role::ReadsCollectionInput' => {
		-alias    => { validate_args => '_validate_args_for_reads_collection_input' },
		-excludes => 'validate_args',
	},
	'CLIPSeqTools::Role::OutputPrefix' => {
		-alias    => { validate_args => '_validate_args_for_output_prefix' },
		-excludes => 'validate_args',
	},
	'CLIPSeqTools::Role::Verbose' => {
		-alias    => { validate_args => '_validate_args_for_verbose' },
		-excludes => 'validate_args',
	},
	'CLIPSeqTools::Role::Help' => {
		-alias    => { validate_args => '_check_help_flag' },
		-excludes => 'validate_args',
	};

	
#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub description {
	'Measure the percent of the genome that is covered by the reads of a library';
}

sub validate_args {
	my ($self, $opt, $args) = @_;
	
	$self->_check_help_flag;
	$self->_validate_args_for_reads_collection_input;
	$self->_validate_args_for_output_prefix;
	$self->usage_error('File with sizes for reference alignment sequences is required') if !$self->rname_sizes;
}

sub execute {
	my ($self, $opt, $args) = @_;
	
	
	warn "Reading sizes for reference alignment sequences\n" if $self->verbose;
	my %rname_sizes = $self->read_rname_sizes;
	
	
	warn "Creating reads collection\n" if $self->verbose;
	my $reads_collection = $self->reads_collection;
	my @rnames = $reads_collection->rnames_for_all_strands;
	
	
	warn "Creating output path\n" if $self->verbose;
	$self->make_path_for_output_prefix();
	
	
	warn "Calculating genome coverage\n" if $self->verbose;
	my $total_genome_coverage = 0;
	my $total_genome_length = 0;
	open(my $OUT, '>', $self->o_prefix.'genome_coverage.tab');
	say $OUT join("\t", 'rname', 'covered_area', 'size', 'percent_covered');
	foreach my $rname (@rnames) {
		warn "Working for $rname\n" if $self->verbose;
		my $pdl = PDL->zeros(PDL::byte(), $rname_sizes{$rname});
		
		$reads_collection->foreach_record_on_rname_do($rname, sub {
			$pdl->slice([$_[0]->start, $_[0]->stop]) .= 1;
			return 0;
		});
		
		my $covered_area = $pdl->sum();
		say $OUT join("\t", $rname, $covered_area, $rname_sizes{$rname}, $covered_area/$rname_sizes{$rname}*100);
		
		$total_genome_coverage += $covered_area;
		$total_genome_length += $rname_sizes{$rname};
	}
	say $OUT join("\t", 'Total', $total_genome_coverage, $total_genome_length, $total_genome_coverage/$total_genome_length*100);
	close $OUT;
}

sub read_rname_sizes {
	my ($self) = @_;
	
	my %rname_size;
	open (my $CHRSIZE, '<', $self->rname_sizes);
	while (my $line = <$CHRSIZE>) {
		chomp $line;
		my ($chr, $size) = split(/\t/, $line);
		$rname_size{$chr} = $size;
	}
	close $CHRSIZE;
	return %rname_size;
}




1;