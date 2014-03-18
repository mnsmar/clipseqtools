=head1 NAME

CLIPSeqTools::PlotApp::genomic_distribution - Create plots for script genomic_distribution.

=head1 SYNOPSIS

clipseqtools genomic_distribution [options/parameters]

=head1 DESCRIPTION

Create plots for script genomic_distribution.

=head1 OPTIONS

  Input.
    -file <Str>            input file.

  Output
    -o_prefix <Str>        output path prefix. Script will create and add
                           extension to path. Default: ./

    -v --verbose           print progress lines and extra information.
    -h -? --usage --help   print help message
    
=cut

package CLIPSeqTools::PlotApp::genomic_distribution;


# Make it an app command
use MooseX::App::Command;
extends 'CLIPSeqTools::PlotApp';


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use namespace::autoclean;
use File::Spec;


#######################################################################
#######################   Command line options   ######################
#######################################################################
option 'file' => (
	is            => 'rw',
	isa           => 'Str',
	required      => 1,
	documentation => 'input file.',
);

#######################################################################
##########################   Consume Roles   ##########################
#######################################################################
with 
	"CLIPSeqTools::Role::OutputPrefixOption" => {
		-alias    => { validate_args => '_validate_args_for_output_prefix_option' },
		-excludes => 'validate_args',
	},
	"CLIPSeqTools::Role::VerbosityOption" => {
		-alias    => { validate_args => '_validate_args_for_verbosity_option' },
		-excludes => 'validate_args',
	};

	
#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {
	my ($self) = @_;
	
	$self->_validate_args_for_output_prefix_option;
	$self->_validate_args_for_verbosity_option;
}

sub run {
	my ($self) = @_;
	
	warn "Validating arguments\n" if $self->verbose;
	$self->validate_args();
	
	warn "Creating output path\n" if $self->verbose;
	$self->make_path_for_output_prefix();
	
	warn "Building output file\n" if $self->verbose;
	my (undef, undef, $filename) = File::Spec->splitpath($self->file);
	$filename =~ s/\.tab$//;
	my $figfile = $self->o_prefix . $filename . '.pdf';
	
	warn "Creating plots\n" if $self->verbose;
	system q{Rscript bin/plot_genomic_distribution.R --ifile=} . $self->file . q{ --figfile=} . $figfile;
}

1;
