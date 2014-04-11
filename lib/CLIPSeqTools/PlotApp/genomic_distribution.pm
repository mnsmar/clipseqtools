=head1 NAME

CLIPSeqTools::PlotApp::genomic_distribution - Create plots for script genomic_distribution.

=head1 SYNOPSIS

clipseqtools-plot genomic_distribution [options/parameters]

=head1 DESCRIPTION

Create plots for script genomic_distribution.

=head1 OPTIONS

  Input.
    --file <Str>           input file.

  Output
    --o_prefix <Str>       output path prefix. Script will create and add
                           extension to path. [Default: ./]

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
use Statistics::R;


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
	"CLIPSeqTools::Role::Option::OutputPrefix" => {
		-alias    => { validate_args => '_validate_args_for_output_prefix' },
		-excludes => 'validate_args',
	};

	
#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {
	my ($self) = @_;
	
	$self->_validate_args_for_output_prefix;
}

sub run {
	my ($self) = @_;
	
	warn "Validating arguments\n" if $self->verbose;
	$self->validate_args();
	
	warn "Creating output path\n" if $self->verbose;
	$self->make_path_for_output_prefix();
	
	warn "Creating plots with R\n" if $self->verbose;
	$self->run_R;
}

sub run_R {
	my ($self) = @_;
	
	# Build output file by replacing suffix .tab with .pdf
	my (undef, undef, $filename) = File::Spec->splitpath($self->file);
	$filename =~ s/\.tab$//;
	my $figfile = $self->o_prefix . $filename . '.pdf';
	
	# Start R
	my $R = Statistics::R->new();
	
	# Pass arguments to R
	$R->set('ifile', $self->file);
	$R->set('figfile', $figfile);
	
	# Load R libraries
	$R->run(q{library(plotrix)});
	$R->run(q{library(RColorBrewer)});
	
	# Prepare color palette
	$R->run(q{mypalette = brewer.pal(4, "RdYlBu")});
	
	# Read table with data - Do exra calulations
	$R->run(q{idata = read.delim(ifile)});
	$R->run(q{idata$percent = (idata$count / idata$total) * 100});
	
	# Do plots
	$R->run(q{pdf(figfile, width=14)});
	$R->run(q{par(mfrow = c(1, 2), mar=c(9.5, 4.1, 4.1, 2.1));});
	$R->run(q{barp(height=idata$percent, names.arg=idata$category, col=c(rep("black",2), rep("darkgrey",3), rep("grey",3), rep("lightgrey",3), rep("lightblue",3)), staxx=TRUE, srt=45, ylim=c(0,100), ylab="Percent of total reads");});
	$R->run(q{barp(height=idata$count, names.arg=idata$category, col=c(rep("black",2), rep("darkgrey",3), rep("grey",3), rep("lightgrey",3), rep("lightblue",3)), staxx=TRUE, srt=45, ylab="Number of reads");});
	$R->run(q{graphics.off()});
	
	# Close R
	$R->stop();
}

1;
