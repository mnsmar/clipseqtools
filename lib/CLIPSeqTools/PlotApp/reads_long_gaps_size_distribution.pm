=head1 NAME

CLIPSeqTools::PlotApp::reads_long_gaps_size_distribution - Create plots for script reads_long_gaps_size_distribution.

=head1 SYNOPSIS

clipseqtools-plot reads_long_gaps_size_distribution [options/parameters]

=head1 DESCRIPTION

Create plots for script reads_long_gaps_size_distribution.

=head1 OPTIONS

  Input.
    --file <Str>                 file with long gaps distribution.

  Output
    --o_prefix <Str>             output path prefix. Script will create and add
                                 extension to path. Default: ./

    -v --verbose                 print progress lines and extra information.
    -h -? --usage --help         print help message

=cut

package CLIPSeqTools::PlotApp::reads_long_gaps_size_distribution;


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
	
	$self->_validate_args_for_output_prefix_option;
	$self->_validate_args_for_verbosity_option;
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
	
	# Create groups of scores
	$R->run(q{mybreaks = c(seq(0,500,100), seq(1000,5000,2000), seq(10000,50000,20000), Inf)});
	$R->run(q{idata$size_group = cut(idata$gap_size, breaks=mybreaks, dig.lab=4)});
	
	# Aggregate (sum) counts for size groups
	$R->run(q{aggregate_counts = tapply(idata$count, idata$size_group , sum)});
	
	# Do plots
	$R->run(q{pdf(figfile, width=14)});
	$R->run(q{par(mfrow = c(1, 2), cex.lab=1.2, cex.axis=1.2, cex.main=1.2, lwd=1.2, oma=c(0, 0, 2, 0), mar=c(9.1, 5.1, 4.1, 2.1))});
	
	$R->run(q{plot(aggregate_counts, type="b", xaxt="n", pch=19, xlab = NA, ylab="Number of gaps", main="Number of gaps with given size")});
	$R->run(q{axis(1, at=1:length(aggregate_counts), labels=names(aggregate_counts), las=2)});
	$R->run(q{mtext(side = 1, "Gap size", line = 7)});
	
	$R->run(q{plot((aggregate_counts / sum(idata$count)) * 100, type="b", xaxt="n", pch=19, xlab = NA, ylab="Percent of gaps (%)", main="Percent of gaps with given size")});
	$R->run(q{axis(1, at=1:length(aggregate_counts), labels=names(aggregate_counts), las=2)});
	$R->run(q{mtext(side = 1, "Gap size", line = 7)});
	
	$R->run(q{graphics.off()});
	
	# Close R
	$R->stop();
}


1;
