=head1 NAME

CLIPSeqTools::App::genomic_distribution - Count reads on genes, repeats, exons, etc.

=head1 SYNOPSIS

genomic_distribution.pl [options/parameters]

=head1 DESCRIPTION

Measure the number of reads that align to each genome wide annotation
such as genic, intergenic, repeats, exonic, intronic, etc.

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
    -v --verbose           print progress lines and extra information.
    -h -? --usage --help   print help message

=cut

package CLIPSeqTools::App::genomic_distribution;


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
use List::Util qw(sum max);


#######################################################################
##########################   Consume Roles   ##########################
#######################################################################
with 
	"CLIPSeqTools::Role::ReadsCollectionInput" => {
		-alias    => { validate_args => '_validate_args_for_reads_collection_input' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::OutputPrefixOption" => {
		-alias    => { validate_args => '_validate_args_for_output_prefix_option' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::VerbosityOption" => {
		-alias    => { validate_args => '_validate_args_for_verbosity_option' },
		-excludes => 'validate_args',
	};


#######################################################################
###################   Silence command line options   ##################
#######################################################################
option 'type' => (
	is            => 'ro',
	isa           => 'Str',
	default       => 'DBIC',
	documentation => 'input type (eg. DBIC, BED, SAM).',
);

option 'file' => (
	is            => 'ro',
	isa           => 'Str',
	documentation => 'input file. Only works if type specifies a file type.',
);


#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {
	my ($self, $opt, $args) = @_;
	
	$self->_validate_args_for_reads_collection_input;
	$self->_validate_args_for_output_prefix_option;
	$self->_validate_args_for_verbosity_option;
}

sub run {
	my ($self, $opt, $args) = @_;
	
	warn "Validating arguments\n" if $self->verbose;
	$self->validate_args();
	
	warn "Creating reads collection\n" if $self->verbose;
	my $reads_collection = $self->reads_collection;
	$reads_collection->schema->storage->debug(1) if $self->verbose;

	warn "Preparing reads resultset\n" if $self->verbose;
	my $reads_rs = $reads_collection->resultset;

	warn "Counting reads for each annotation\n" if $self->verbose;
	my %counts;

	$counts{'total'} = $reads_rs->get_column('copy_number')->sum;

	$counts{'repeats'} = $reads_rs->search({
		rmsk => {'!=', undef}
	})->get_column('copy_number')->sum;

	$counts{'intergenic'} = $reads_rs->search({
		transcript => undef,
		rmsk => undef
	})->get_column('copy_number')->sum;

	$counts{'genic'} = $reads_rs->search({
		transcript => {'!=', undef},
	})->get_column('copy_number')->sum;

	$counts{'exonic'} = $reads_rs->search({
		transcript => {'!=', undef},
		exon       => {'!=', undef},
	})->get_column('copy_number')->sum;

	$counts{'intronic'} = $reads_rs->search({
		transcript => {'!=', undef},
		exon       => undef,
	})->get_column('copy_number')->sum;

	$counts{'genic-norepeat'} = $reads_rs->search({
		transcript => {'!=', undef},
		rmsk       => undef
	})->get_column('copy_number')->sum;

	$counts{'exonic-norepeat'} = $reads_rs->search({
		exon => {'!=', undef},
		rmsk => undef
	})->get_column('copy_number')->sum;

	$counts{'intronic-norepeat'} = $reads_rs->search({
		transcript => {'!=', undef},
		exon       => undef,
		rmsk       => undef
	})->get_column('copy_number')->sum;

	# Coding transcripts
	$counts{'genic-coding-norepeat'} = $reads_rs->search({
		coding_transcript => {'!=', undef},
		rmsk              => undef
	})->get_column('copy_number')->sum;

	$counts{'intronic-coding-norepeat'} = $reads_rs->search({
		coding_transcript => {'!=', undef},
		exon              => undef,
		rmsk              => undef
	})->get_column('copy_number')->sum;

	$counts{'exonic-coding-norepeat'} = $reads_rs->search({
		coding_transcript => {'!=', undef},
		exon              => {'!=', undef},
		rmsk              => undef
	})->get_column('copy_number')->sum;

	$counts{'utr5-exonic-coding-norepeat'} = $reads_rs->search({
		coding_transcript => {'!=', undef},
		exon              => {'!=', undef},
		utr5              => {'!=', undef},
		rmsk              => undef
	})->get_column('copy_number')->sum;

	$counts{'cds-exonic-coding-norepeat'} = $reads_rs->search({
		coding_transcript => {'!=', undef},
		exon              => {'!=', undef},
		cds              => {'!=', undef},
		rmsk              => undef
	})->get_column('copy_number')->sum;

	$counts{'utr3-exonic-coding-norepeat'} = $reads_rs->search({
		coding_transcript => {'!=', undef},
		exon              => {'!=', undef},
		utr3              => {'!=', undef},
		rmsk              => undef
	})->get_column('copy_number')->sum;


	warn "Creating output path\n" if $self->verbose;
	$self->make_path_for_output_prefix();


	warn "Printing results\n" if $self->verbose;
	open (my $OUT, '>', $self->o_prefix.'genomic_distribution.tab');
	print $OUT 
		join("\t", 'category',                     'count',                                'total')."\n".
		
		join("\t", 'Repeat',                       $counts{'repeats'},                     $counts{'total'})."\n".
		join("\t", 'Intergenic (-repeat)',         $counts{'intergenic'},                  $counts{'total'})."\n".
		join("\t", 'Genic',                        $counts{'genic'},                       $counts{'total'})."\n".
		join("\t", 'Intronic',                     $counts{'intronic'},                    $counts{'total'})."\n".
		join("\t", 'Exonic',                       $counts{'exonic'},                      $counts{'total'})."\n".
		join("\t", 'Genic (-repeat)',              $counts{'genic-norepeat'},              $counts{'total'})."\n".
		join("\t", 'Intronic (-repeat)',           $counts{'intronic-norepeat'},           $counts{'total'})."\n".
		join("\t", 'Exonic (-repeat)',             $counts{'exonic-norepeat'},             $counts{'total'})."\n".
		join("\t", 'Genic (+code -repeat)',        $counts{'genic-coding-norepeat'},       $counts{'total'})."\n".
		join("\t", 'Intronic (+code -repeat)',     $counts{'intronic-coding-norepeat'},    $counts{'total'})."\n".
		join("\t", 'Exonic (+code -repeat)',       $counts{'exonic-coding-norepeat'},      $counts{'total'})."\n".
		join("\t", '5UTR (+exonic +code -repeat)', $counts{'utr5-exonic-coding-norepeat'}, $counts{'total'})."\n".
		join("\t", 'CDS (+exonic +code -repeat)',  $counts{'cds-exonic-coding-norepeat'},  $counts{'total'})."\n".
		join("\t", '3UTR (+exonic +code -repeat)', $counts{'utr3-exonic-coding-norepeat'}, $counts{'total'})."\n";
	close $OUT;
}


1;
