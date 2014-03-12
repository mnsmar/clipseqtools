=head1 NAME

CLIPSeqTools::App::Command::libraries_overlap_stats - Count reads of library A that overlap those of reference library B.

=head1 SYNOPSIS

libraries_overlap_stats.pl [options/parameters]

Count reads of library A that overlap those of reference library B.

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

  Input options for reference library.
    -r_type <Str>          input type (eg. DBIC, BED).
    -r_file <Str>          input file. Only works if type specifies a file type.
    -r_driver <Str>        driver for database connection (eg. mysql, SQLite). Only works if type is DBIC.
    -r_database <Str>      database name or path to database file for file based databases (eg. SQLite). Only works if type is DBIC.
    -r_table <Str>         database table. Only works if type is DBIC.
    -r_host <Str>          hostname for database connection. Only works if type is DBIC.
    -r_user <Str>          username for database connection. Only works if type is DBIC.
    -r_password <Str>      password for database connection. Only works if type is DBIC.
    -r_records_class <Str> type of records stored in database (Default: GenOO::Data::DB::DBIC::Species::Schema::SampleResultBase::v3).
    -r_filter <Filter>     filter library. Option can be given multiple times.
                           Filter syntax: column_name="pattern"
                             e.g. -r_filter deletion="def" -r_filter rmsk="undef" to keep reads with deletions and not repeat masked.
                             e.g. -r_filter query_length=">31" -r_filter query_length="<=50" to keep reads longer than 31 and shorter or   equal to 50.
                           Supported operators: ">", ">=", "<", "<=", "=", "!=","def", "undef"

  Other input.
    -rname_sizes <Str>     file with sizes for reference alignment sequences (rnames). Must be tab

  Output
    -o_prefix <Str>        output path prefix. Script adds an extension to path. If path does not exist it will be created. Default: ./

  Other options.
    -v --verbose           print progress lines and extra information.
    -h -? --usage --help   print help message

=head1 DESCRIPTION

Measure the distribution of reads along idealized exons and introns.
Split the exons and introns of coding transcripts in bins and measure the read density in each bin.

=cut

package CLIPSeqTools::App::Command::libraries_overlap_stats;


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use Moose;
use namespace::autoclean;
use File::Spec;
use PDL::Lite; $PDL::BIGPDL = 0; $PDL::BIGPDL++; # enable huge pdls


extends 'MooseX::App::Cmd::Command'; # Declare that class is a command


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
with 
	"CLIPSeqTools::Role::ReadsCollectionInput" => {
		-alias    => { validate_args => '_validate_args_for_reads_collection_input' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::ReadsReferenceCollectionInput" => {
		-alias    => { validate_args => '_validate_args_for_reads_r_collection_input' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::OutputPrefixOption" => {
		-alias    => { validate_args => '_validate_args_for_output_prefix_option' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::VerbosityOption" => {
		-alias    => { validate_args => '_validate_args_for_verbosity_option' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::HelpOption" => {
		-alias    => { validate_args => '_check_help_flag' },
		-excludes => 'validate_args',
	};

	
#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub description {
	q(Measure the distribution of reads along idealized exons and introns.)."\n". 
	q(Split the exons and introns of coding transcripts in bins and measure the read density in each bin.);
}

sub validate_args {
	my ($self, $opt, $args) = @_;
	
	$self->_check_help_flag;
	$self->_validate_args_for_reads_collection_input;
	$self->_validate_args_for_reads_r_collection_input;
	$self->_validate_args_for_output_prefix_option;
	$self->_validate_args_for_verbosity_option;
}

sub execute {
	my ($self, $opt, $args) = @_;
	
	warn "Reading sizes for reference alignment sequences\n" if $self->verbose;
	my %rname_sizes = $self->read_rname_sizes;

	warn "Creating reads collection\n" if $self->verbose;
	my $reads_collection = $self->reads_collection;
	my @rnames = $reads_collection->rnames_for_all_strands;

	warn "Creating reference reads collection\n" if $self->verbose;
	my $r_reads_collection = $self->r_reads_collection;

	warn "Measuring the overlap of the primary library with the reference\n" if $self->verbose;
	my $total_copy_number = 0;       # The total copy number of primary records
	my $total_records = 0;           # The total number of primary records
	my $overlapping_copy_number = 0; # The total copy number of primary records that overlap the reference
	my $overlapping_records = 0;     # The total number of primary records that overlap the reference
	foreach my $rname (@rnames) {
		warn " Annotating $rname with reference records\n" if $self->verbose;
		my $rname_size = $rname_sizes{$rname};
		my $pdl_plus   = PDL->zeros(PDL::byte(), $rname_size);
		my $pdl_minus  = PDL->zeros(PDL::byte(), $rname_size);
		
		$r_reads_collection->foreach_record_on_rname_do($rname, sub {
			my ($r_record) = @_;
			
			my $coords = [$r_record->start, $r_record->stop];
			$pdl_plus->slice($coords)  .= 1 if $r_record->strand == 1;
			$pdl_minus->slice($coords) .= 1 if $r_record->strand == -1;
			
			return 0;
		});
		
		
		warn " Parsing primary records on $rname and checking for overlap with reference\n" if $self->verbose;
		$reads_collection->foreach_record_on_rname_do($rname, sub {
			my ($p_record) = @_;
			
			my $overlap = 0;
			my $coords = [$p_record->start, $p_record->stop];
			$overlap = $pdl_plus->slice($coords)->sum() if $p_record->strand == 1;
			$overlap = $pdl_minus->slice($coords)->sum() if $p_record->strand == -1;
			
			if ($overlap) {
				$overlapping_copy_number += $p_record->copy_number;
				$overlapping_records += 1;
			}
			
			$total_copy_number += $p_record->copy_number;
			$total_records += 1;
			
			return 0;
		});
	}

	warn "Creating output path\n" if $self->verbose;
	$self->make_path_for_output_prefix();

	warn "Printing results\n" if $self->verbose;
	open (my $OUT, '>', $self->o_prefix.'libraries_overlap_stats.tab');
	say $OUT join("\t", 'total_records', 'total_copy_number', 'overlapping_records', 'overlapping_copy_number', 'overlapping_records_percent', 'overlapping_copy_number_percent');
	say $OUT join("\t", $total_records, $total_copy_number, $overlapping_records, $overlapping_copy_number, ($overlapping_records / $total_records) * 100, ($overlapping_copy_number / $total_copy_number) * 100);
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
