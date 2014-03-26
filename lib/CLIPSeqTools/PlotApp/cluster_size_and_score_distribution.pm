=head1 NAME

CLIPSeqTools::PlotApp::cluster_size_and_score_distribution - Create plots for script cluster_size_and_score_distribution.

=head1 SYNOPSIS

clipseqtools-plot cluster_size_and_score_distribution [options/parameters]

=head1 DESCRIPTION

Create plots for script cluster_size_and_score_distribution.

=head1 OPTIONS

  Input.
    --cluster_sizes_file <Str>   file with cluster sizes distribution.
    --cluster_scores_file <Str>  file with cluster scores distribution.

  Output
    --o_prefix <Str>             output path prefix. Script will create and add
                                 extension to path. Default: ./

    -v --verbose                 print progress lines and extra information.
    -h -? --usage --help         print help message

=cut

package CLIPSeqTools::PlotApp::cluster_size_and_score_distribution;


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
option 'cluster_sizes_file' => (
	is            => 'rw',
	isa           => 'Str',
	required      => 1,
	documentation => 'file with cluster sizes distribution.',
);

option 'cluster_scores_file' => (
	is            => 'rw',
	isa           => 'Str',
	required      => 1,
	documentation => 'file with cluster scores distribution.',
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
	
	warn "Creating plots for cluster sizes with R\n" if $self->verbose;
	$self->run_R_for_cluster_sizes;
	
	warn "Creating plots for cluster scores with R\n" if $self->verbose;
	$self->run_R_for_cluster_scores;
}

sub run_R_for_cluster_scores {
	my ($self) = @_;
	
	# Build output file by replacing suffix .tab with .pdf
	my (undef, undef, $filename) = File::Spec->splitpath($self->cluster_scores_file);
	$filename =~ s/\.tab$//;
	my $figfile = $self->o_prefix . $filename . '.pdf';
	
	# Start R
	my $R = Statistics::R->new();
	
	# Pass arguments to R
	$R->set('ifile', $self->cluster_scores_file);
	$R->set('figfile', $figfile);
	
	# Load R libraries
	$R->run(q{library(RColorBrewer)});
	
	# Disable scientific notation
	$R->run(q{options(scipen=999)});
	
	# Prepare color palette
	$R->run(q{mypalette = brewer.pal(4, "RdYlBu")});
	
	# Read table with data
	$R->run(q{idata = read.delim(ifile)});
	
	# Create column with total number of reads in clusters of each score
	$R->run(q{idata$contained_reads_per_score = idata$cluster_score * idata$count});
	
	# Create groups of scores
	$R->run(q{mybreaks = c(seq(0,5,1), seq(10,20,5), seq(40,100,20), seq(200,600,200), 1000, Inf)});
	$R->run(q{idata$score_group = cut(idata$cluster_score, breaks=mybreaks, dig.lab=4)});
	
	# Aggregate (sum) counts for score groups
	$R->run(q{aggregate_counts = tapply(idata$count, idata$score_group , sum)});
	$R->run(q{aggregate_contained_reads_per_score = tapply(idata$contained_reads_per_score, idata$score_group , sum)});
	
	# Do plots
	$R->run(q{pdf(figfile, width=21)});
	$R->run(q{par(mfrow = c(1, 3), cex.lab=1.5, cex.axis=1.5, cex.main=1.5, lwd=1.5, oma=c(0, 0, 2, 0), mar=c(9.1, 5.1, 4.1, 2.1))});
	
	$R->run(q{plot(aggregate_counts, type="b", xaxt="n", pch=19, xlab = NA, log="y", ylab="Number of clusters (log)", main="Number of clusters with given score")});
	$R->run(q{axis(1, at=1:length(aggregate_counts), labels=names(aggregate_counts), las=2)});
	$R->run(q{mtext(side = 1, "Cluster score", line = 6)});
	
	$R->run(q{plot((aggregate_counts / sum(aggregate_counts, na.rm=TRUE)) * 100, type="b", xaxt="n", pch=19, xlab = NA, ylab="Percent of clusters (%)", main="Percent of clusters with given score")});
	$R->run(q{axis(1, at=1:length(aggregate_counts), labels=names(aggregate_counts), las=2)});
	$R->run(q{mtext(side = 1, "Cluster score", line = 6)});
	
	$R->run(q{plot((aggregate_contained_reads_per_score / sum(aggregate_contained_reads_per_score, na.rm=TRUE)) * 100, type="b", xaxt="n", pch=19, xlab = NA, ylab="Percent of reads (%)", main="Percent of reads contained in given cluster score")});
	$R->run(q{axis(1, at=1:length(aggregate_counts), labels=names(aggregate_counts), las=2)});
	$R->run(q{mtext(side = 1, "Cluster score", line = 6)});
	
	$R->run(q{graphics.off()});
	
	# Close R
	$R->stop();
}

sub run_R_for_cluster_sizes {
	my ($self) = @_;
	
	# Build output file by replacing suffix .tab with .pdf
	my (undef, undef, $filename) = File::Spec->splitpath($self->cluster_sizes_file);
	$filename =~ s/\.tab$//;
	my $figfile = $self->o_prefix . $filename . '.pdf';
	
	# Start R
	my $R = Statistics::R->new();
	
	# Pass arguments to R
	$R->set('ifile', $self->cluster_sizes_file);
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
	$R->run(q{mybreaks = c(10, seq(50,500,50), 1000, Inf)});
	$R->run(q{idata$size_group = cut(idata$cluster_size, breaks=mybreaks, dig.lab=4)});
	
	# Aggregate (sum) counts for size groups
	$R->run(q{aggregate_counts = tapply(idata$count, idata$size_group , sum)});
	
	# Do plots
	$R->run(q{pdf(figfile, width=14)});
	$R->run(q{par(mfrow = c(1, 2), cex.lab=1.2, cex.axis=1.2, cex.main=1.2, lwd=1.2, oma=c(0, 0, 2, 0), mar=c(9.1, 5.1, 4.1, 2.1))});
	
	$R->run(q{plot(aggregate_counts, type="b", xaxt="n", pch=19, xlab = NA, log="y", ylab="Number of clusters (log)", main="Number of clusters with given size")});
	$R->run(q{axis(1, at=1:length(aggregate_counts), labels=names(aggregate_counts), las=2)});
	$R->run(q{mtext(side = 1, "Cluster size", line = 6)});
	
	$R->run(q{plot((aggregate_counts / sum(aggregate_counts, na.rm=TRUE)) * 100, type="b", xaxt="n", pch=19, xlab = NA, ylab="Percent of clusters (%)", main="Percent of clusters with given size")});
	$R->run(q{axis(1, at=1:length(aggregate_counts), labels=names(aggregate_counts), las=2)});
	$R->run(q{mtext(side = 1, "Cluster size", line = 6)});
	
	$R->run(q{graphics.off()});
	
	# Close R
	$R->stop();
}


1;
