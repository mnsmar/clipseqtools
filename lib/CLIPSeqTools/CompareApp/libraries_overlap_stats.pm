=head1 NAME

CLIPSeqTools::CompareApp::libraries_overlap_stats - Count reads of library A that overlap those of reference library B.

=head1 SYNOPSIS

clipseqtools libraries_overlap_stats [options/parameters]

=head1 DESCRIPTION

Count reads of library A that overlap those of reference library B.

=head1 OPTIONS

  Input options for library.
    -type <Str>            input type (eg. DBIC, BED).
    -file <Str>            input file. Only if type is a file type.
    -driver <Str>          driver for database connection (eg. mysql,
                           SQLite).
    -database <Str>        database name or path to database file for file
                           based databases (eg. SQLite).
    -table <Str>           database table.
    -host <Str>            hostname for database connection.
    -user <Str>            username for database connection.
    -password <Str>        password for database connection.
    -records_class <Str>   type of records stored in database.
    -filter <Filter>       filter library. May be used multiple times.
                           Syntax: column_name="pattern"
                           e.g. keep reads with deletions AND not repeat
                                masked AND longer than 31
                                -filter deletion="def" 
                                -filter rmsk="undef" .
                                -filter query_length=">31".
                           Operators: >, >=, <, <=, =, !=, def, undef

  Input options for reference library.
    -r_type <Str>          input type (eg. DBIC, BED).
    -r_file <Str>          input file. Only if r_type is a file type.
    -r_driver <Str>        driver for database connection (eg. mysql, 
                           SQLite).
    -r_database <Str>      database name or path to database file for file
                           based databases (eg. SQLite).
    -r_table <Str>         database table.
    -r_host <Str>          hostname for database connection.
    -r_user <Str>          username for database connection.
    -r_password <Str>      password for database connection.
    -r_records_class <Str> type of records stored in database.
    -r_filter <Filter>     same as filter but for reference library.

  Other input.
    -rname_sizes <Str>     file with sizes for reference alignment sequences
                           (rnames). Must be tab delimited (chromosome\tsize)
                           with one line per rname.

  Output
    -o_prefix <Str>        output path prefix. Script will create and add
                           extension to path. Default: ./

  Other options.
    -v --verbose           print progress lines and extra information.
    -h -? --usage --help   print help message

=cut

package CLIPSeqTools::CompareApp::libraries_overlap_stats;


# Make it an app command
use MooseX::App::Command;
extends 'CLIPSeqTools::CompareApp';


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use namespace::autoclean;
use File::Spec;
use PDL::Lite; $PDL::BIGPDL = 0; $PDL::BIGPDL++; # enable huge pdls


#######################################################################
#######################   Command line options   ######################
#######################################################################
option 'rname_sizes' => (
	is            => 'rw',
	isa           => 'Str',
	required      => 1,
	documentation => 'file with sizes for reference alignment sequences (rnames). Must be tab delimited (chromosome\tsize) with one line per rname.',
);


#######################################################################
##########################   Consume Roles   ##########################
#######################################################################
with 
	"CLIPSeqTools::Role::Option::Library" => {
		-alias    => { validate_args => '_validate_args_for_library' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::Option::ReferenceLibrary" => {
		-alias    => { validate_args => '_validate_args_for_reference_library' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::Option::OutputPrefix" => {
		-alias    => { validate_args => '_validate_args_for_output_prefix' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::Option::Verbosity" => {
		-alias    => { validate_args => '_validate_args_for_verbosity' },
		-excludes => 'validate_args',
	};

	
#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {
	my ($self) = @_;
	
	$self->_validate_args_for_library;
	$self->_validate_args_for_reference_library;
	$self->_validate_args_for_output_prefix;
	$self->_validate_args_for_verbosity;
}

sub run {
	my ($self) = @_;
	
	warn "Validating arguments\n" if $self->verbose;
	$self->validate_args();
	
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
