=head1 NAME

CLIPSeqTools::PlotApp::size_distribution - Create plots for script size_distribution.

=head1 SYNOPSIS

clipseqtools-plot size_distribution [options/parameters]

=head1 DESCRIPTION

Create plots for script size_distribution.

=head1 OPTIONS

  Input.
    --file <Str>                 file with long gaps distribution.

  Output
    --o_prefix <Str>             output path prefix. Script will create and add
                                 extension to path. Default: ./

    -v --verbose                 print progress lines and extra information.
    -h -? --usage --help         print help message

=cut

package CLIPSeqTools::PlotApp::size_distribution;


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
	documentation => 'file with long gaps distribution.',
);


#######################################################################
##########################   Consume Roles   ##########################
#######################################################################
with 
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
	
	$self->_validate_args_for_output_prefix;
	$self->_validate_args_for_verbosity;
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
	$R->run(q{library(RColorBrewer)});
	
	# Disable scientific notation
	$R->run(q{options(scipen=999)});
	
	# Prepare color palette
	$R->run(q{mypalette = brewer.pal(4, "RdYlBu")});
	
	# Read table with data
	$R->run(q{idata = read.delim(ifile)});
	
	# Do plots
	$R->run(q{pdf(figfile, width=14)});
	$R->run(q{par(mfrow = c(1, 2), cex.lab=1.2, cex.axis=1.2, cex.main=1.2, lwd=1.2, oma=c(0, 0, 2, 0), mar=c(5.1, 5.1, 4.1, 2.1))});
	$R->run(q{plot(idata$size, idata$count, type="b", pch=19, xlab="Size", ylab="Number of reads", main="Number of reads with given size")});
	$R->run(q{plot(idata$size, (idata$count / sum(idata$count)) * 100, type="b", pch=19, xlab="Size", ylab="Percent of reads (%)", main="Percent of reads with given size")});
	$R->run(q{graphics.off()});
	
	# Close R
	$R->stop();
}


1;
