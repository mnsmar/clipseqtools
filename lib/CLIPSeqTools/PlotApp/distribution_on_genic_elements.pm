=head1 NAME

CLIPSeqTools::PlotApp::distribution_on_genic_elements - Create plots for script distribution_on_genic_elements.

=head1 SYNOPSIS

clipseqtools-plot distribution_on_genic_elements [options/parameters]

=head1 DESCRIPTION

Create plots for script distribution_on_genic_elements.

=head1 OPTIONS

  Input.
    -file <Str>            input file.

  Output
    -o_prefix <Str>        output path prefix. Script will create and add
                           extension to path. Default: ./

    -v --verbose           print progress lines and extra information.
    -h -? --usage --help   print help message

=cut

package CLIPSeqTools::PlotApp::distribution_on_genic_elements;


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
	$R->run(q{library(RColorBrewer)});
	
	# Prepare color palette
	$R->run(q{mypalette = brewer.pal(4, "RdYlBu")});
	
	# Read table with data
	$R->run(q{idata = read.delim(ifile)});
	
	# Do plots
	$R->run(q{pdf(figfile, width=21)});
	$R->run(q{par(mfrow = c(1, 3), cex.lab=1.5, cex.axis=1.5, cex.main=1.5, lwd=1.5, oma=c(0, 0, 2, 0))});
	$R->run(q{plot(idata$bin[idata$element == 'utr5'], idata$avg_rpkm[idata$element   == 'utr5'], type="b", ylim=c(0, max(idata$avg_rpkm)),   col=mypalette[1], main="5'UTR", xlab="Bin", ylab="Average RPKM")});
	$R->run(q{plot(idata$bin[idata$element == 'cds'],  idata$avg_rpkm[idata$element   == 'cds'],  type="b", ylim=c(0, max(idata$avg_rpkm)),   col=mypalette[2], main="CDS",   xlab="Bin", ylab="Average RPKM")});
	$R->run(q{plot(idata$bin[idata$element == 'utr3'], idata$avg_rpkm[idata$element   == 'utr3'], type="b", ylim=c(0, max(idata$avg_rpkm)),   col=mypalette[4], main="3'UTR", xlab="Bin", ylab="Average RPKM")});
	$R->run(q{plot(idata$bin[idata$element == 'utr5'], idata$avg_counts[idata$element == 'utr5'], type="b", ylim=c(0, max(idata$avg_counts)), col=mypalette[1], main="5'UTR", xlab="Bin", ylab="Average number of reads")});
	$R->run(q{plot(idata$bin[idata$element == 'cds'],  idata$avg_counts[idata$element == 'cds'],  type="b", ylim=c(0, max(idata$avg_counts)), col=mypalette[2], main="CDS",   xlab="Bin", ylab="Average number of reads")});
	$R->run(q{plot(idata$bin[idata$element == 'utr3'], idata$avg_counts[idata$element == 'utr3'], type="b", ylim=c(0, max(idata$avg_counts)), col=mypalette[4], main="3'UTR", xlab="Bin", ylab="Average number of reads")});
	$R->run(q{graphics.off()});
	
	# Close R
	$R->stop();
}


1;
