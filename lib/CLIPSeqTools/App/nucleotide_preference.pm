=head1 NAME

CLIPSeqTools::App::nucleotide_preference - Count nucleotide appearences within reads, per length and per position

=head1 SYNOPSIS

clipseqtools nucleotide_preference [options/parameters]

=head1 DESCRIPTION

Count nucleotide appearences within reads, per length and per position.
Measure the nucleotide composition for each read position and read length.
Measure counts using the reads copy number and without using it.

=head1 OPTIONS

  Input options for library.
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

  Output
    -o_prefix <Str>        output path prefix. Script will create and add
                           extension to path. Default: ./

  Other options.
    -plot                  call plotting script to create plots.
    -v --verbose           print progress lines and extra information.
    -h -? --usage --help   print help message

=cut


package CLIPSeqTools::App::nucleotide_preference;


# Make it an app command
use MooseX::App::Command;
extends 'CLIPSeqTools::App';


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use namespace::autoclean;


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
	$self->_validate_args_for_output_prefix;
	$self->_validate_args_for_verbosity;
}

sub run {
	my ($self) = @_;
	
	warn "Validating arguments\n" if $self->verbose;
	$self->validate_args();

	warn "Creating reads collection\n" if $self->verbose;
	my $reads_collection = $self->reads_collection;

	warn "Counting nucleotide occurences within reads\n" if $self->verbose;
	my %nts;
	my %collapsed_nts;
	my %total_nts;
	my %total_collapsed_nts;
	$reads_collection->foreach_record_do( sub{
		my ($record) = @_;
		
		my $seq = $record->sequence;
		my @seq_array = split(//, $seq);
		my $seq_length = length($seq);
		
		for (my $i = 0; $i < @seq_array; $i++){
			my $nt = $seq_array[$i];
			$nts{$nt}{$i}{$seq_length} += $record->copy_number;
			$collapsed_nts{$nt}{$i}{$seq_length}++ ;
			
			$total_nts{$i}{$seq_length} += $record->copy_number;
			$total_collapsed_nts{$i}{$seq_length}++ ;
		}

		return 0;
	});

	warn "Creating output path\n" if $self->verbose;
	$self->make_path_for_output_prefix();

	warn "Printing output\n" if $self->verbose;
	open(my $OUT, '>', $self->o_prefix.'nucleotide_preference.tab');
	say $OUT join("\t", 'nt', 'read_position', 'read_length', 'count', 'count_no_copy_number', 'count_percent', 'count_no_copy_number_percent');
	foreach my $nt (keys %nts){
		foreach my $i (sort {$a <=> $b} keys %{$nts{$nt}}){
			foreach my $length (sort {$a <=> $b} keys %{$nts{$nt}{$i}}){
				say $OUT join("\t",($nt, $i, $length, $nts{$nt}{$i}{$length}, $collapsed_nts{$nt}{$i}{$length},($nts{$nt}{$i}{$length}/$total_nts{$i}{$length}), ($collapsed_nts{$nt}{$i}{$length}/$total_collapsed_nts{$i}{$length})));
			}
		}
	}
	
	if ($self->plot) {
		warn "Creating plot\n" if $self->verbose;
		CLIPSeqTools::PlotApp->initialize_command_class('CLIPSeqTools::PlotApp::nucleotide_preference', 
			file     => $self->o_prefix.'nucleotide_preference.tab',
			o_prefix => $self->o_prefix
		)->run();
	}
}


1;
