=head1 NAME

CLIPSeqTools::App::reads_long_gaps_size_distribution - Measure size distribution of long alignment gaps produced by a gap aware aligner.

=head1 SYNOPSIS

clipseqtools reads_long_gaps_size_distribution [options/parameters]

=head1 DESCRIPTION

Measure size distribution of gaps within alignments produced by a gap
aware aligner. Reads that have been aligned with a gap aware aligner
might map in two distant points on the reference sequence with the
intermediate region usually marked in the cigar sting with Ns.
Measure the size of these intermediate regions and create a size
distribution.

=head1 OPTIONS

  Input options for library.
    --type <Str>           input type (eg. DBIC, BED).
    --file <Str>           input file. Only works if type is a file type.
    --driver <Str>         driver for database connection (eg. mysql,
                           SQLite).
    --database <Str>       database name or path to database file for file
                           based databases (eg. SQLite).
    --table <Str>          database table.
    --host <Str>           hostname for database connection.
    --user <Str>           username for database connection.
    --password <Str>       password for database connection.
    --records_class <Str>  type of records stored in database.
    --filter <Filter>      filter library. May be used multiple times.
                           Syntax: column_name="pattern"
                           e.g. keep reads with deletions AND not repeat
                                masked AND longer than 31
                                -filter deletion="def" 
                                -filter rmsk="undef" .
                                -filter query_length=">31".
                           Operators: >, >=, <, <=, =, !=, def, undef

  Output
    --o_prefix <Str>       output path prefix. Script will create and add
                           extension to path. Default: ./

  Other options.
    --plot                 call plotting script to create plots.
    -v --verbose           print progress lines and extra information.
    -h -? --usage --help   print help message

=cut

package CLIPSeqTools::App::reads_long_gaps_size_distribution;


# Make it an app command
use MooseX::App::Command;
extends 'CLIPSeqTools::App';


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use namespace::autoclean;
use File::Spec;
use List::Util qw(max);


#######################################################################
##########################   Consume Roles   ##########################
#######################################################################
with 
	"CLIPSeqTools::Role::ReadsCollectionInput" => {
		-alias    => { validate_args => '_validate_args_for_reads_collection_input' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::PlotOption" => {
		-alias    => { validate_args => '_validate_args_for_plot_option' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::OutputPrefixOption" => {
		-alias    => { validate_args => '_validate_args_for_output_prefix_option' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::Option::Verbosity" => {
		-alias    => { validate_args => '_validate_args_for_verbosity_option' },
		-excludes => 'validate_args',
	};

	
#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {
	my ($self) = @_;
	
	$self->_validate_args_for_reads_collection_input;
	$self->_validate_args_for_plot_option;
	$self->_validate_args_for_output_prefix_option;
	$self->_validate_args_for_verbosity_option;
}

sub run {
	my ($self) = @_;
	
	warn "Validating arguments\n" if $self->verbose;
	$self->validate_args();
	
	warn "Creating reads collection\n" if $self->verbose;
	my $reads_collection = $self->reads_collection;
	$reads_collection->schema->storage->debug(1) if $self->verbose > 1;
	
	warn "Measuring long gaps\n" if $self->verbose;
	my %gap_size_count;
	$reads_collection->foreach_record_do( sub {
		my ($rec) = @_;
		
		my $cigar = $rec->cigar;
		if ($cigar !~ /N/) {
			$gap_size_count{0} += $rec->copy_number;
		}
		else {
			while ($cigar =~ /(\d+)N/g) {
				my $gap_length = $1;
				$gap_size_count{$gap_length} += $rec->copy_number;
			}
		}
		
		return 0;
	});

	warn "Creating output path\n" if $self->verbose;
	$self->make_path_for_output_prefix();
	
	warn "Printing results\n" if $self->verbose;
	open (my $OUT1, '>', $self->o_prefix.'reads_long_gaps_size_distribution.tab');
	say $OUT1 join("\t", 'gap_size', 'count');
	say $OUT1 join("\t", $_, $gap_size_count{$_}) for sort {$a <=> $b} keys %gap_size_count;
	close $OUT1;
	
	if ($self->plot) {
		warn "Creating plot\n" if $self->verbose;
		CLIPSeqTools::PlotApp->initialize_command_class('CLIPSeqTools::PlotApp::reads_long_gaps_size_distribution', 
			file     => $self->o_prefix.'reads_long_gaps_size_distribution.tab',
			o_prefix => $self->o_prefix
		)->run();
	}
}

1;
