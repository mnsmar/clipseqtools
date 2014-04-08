=head1 NAME

CLIPSeqTools::App::nucleotide_composition - Measure nucleotide composition along reads.

=head1 SYNOPSIS

clipseqtools nucleotide_composition [options/parameters]

=head1 DESCRIPTION

Measure nucleotide composition along reads.

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

package CLIPSeqTools::App::nucleotide_composition;


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
use List::Util qw(min max sum);


#######################################################################
##########################   Consume Roles   ##########################
#######################################################################
with 
	"CLIPSeqTools::Role::Option::Library" => {
		-alias    => { validate_args => '_validate_args_for_library' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::Option::Plot" => {
		-alias    => { validate_args => '_validate_args_for_plot' },
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
	$self->_validate_args_for_plot;
	$self->_validate_args_for_output_prefix;
	$self->_validate_args_for_verbosity;
}

sub run {
	my ($self) = @_;
	
	warn "Validating arguments\n" if $self->verbose;
	$self->validate_args();
	
	warn "Creating reads collection\n" if $self->verbose;
	my $reads_collection = $self->reads_collection;
	$reads_collection->schema->storage->debug(1) if $self->verbose > 1;
	
	warn "Measuring nucleotide composition along the reads\n" if $self->verbose;
	my @nt_count;
	my %existent_nts;
	$reads_collection->foreach_record_do( sub {
		my ($rec) = @_;
		
		my @nts = split(//, uc($rec->sequence));
		for my $i (0..$#nts) {
			$nt_count[$i]{$nts[$i]} += $rec->copy_number;
			$existent_nts{$nts[$i]} = 1;
		}
		
		return 0;
	});
	my @sorted_existent_nts = sort keys %existent_nts;
	
	warn "Creating output path\n" if $self->verbose;
	$self->make_path_for_output_prefix();
	
	warn "Printing results\n" if $self->verbose;
	open (my $OUT1, '>', $self->o_prefix.'nucleotide_composition.tab');
	say $OUT1 join("\t", 'position', map {$_.'_count'} @sorted_existent_nts, 'total_count');
	for (my $i=0; $i<@nt_count; $i++) {
		my @counts = map {$nt_count[$i]{$_} || 0} @sorted_existent_nts;
		say $OUT1 join("\t", $i, @counts, sum(@counts));
	}
	close $OUT1;
	
	if ($self->plot) {
		warn "Creating plot\n" if $self->verbose;
		CLIPSeqTools::PlotApp->initialize_command_class('CLIPSeqTools::PlotApp::nucleotide_composition', 
			file     => $self->o_prefix.'nucleotide_composition.tab',
			o_prefix => $self->o_prefix
		)->run();
	}
}

1;
