=head1 NAME

CLIPSeqTools::PreprocessApp::cleanup_alignment - Sort STAR alignments and keep only a single record for multimappers.

=head1 SYNOPSIS

clipseqtools-preprocess cleanup_alignment [options/parameters]

=head1 DESCRIPTION

Sort STAR alignments and keep only a single record for multimappers.

=head1 OPTIONS

  Input.
    --sam <Str>            SAM file with STAR alignments.

  Output
    --o_prefix <Str>       output path prefix. Script will create and add
                           extension to path. [Default: ./]

  Other options.
    -v --verbose           print progress lines and extra information.
    -h -? --usage --help   print help message

=cut

package CLIPSeqTools::PreprocessApp::cleanup_alignment;


# Make it an app command
use MooseX::App::Command;
extends 'CLIPSeqTools::PreprocessApp';


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use namespace::autoclean;


#######################################################################
#######################   Command line options   ######################
#######################################################################
option 'sam' => (
	is            => 'rw',
	isa           => 'Str',
	required      => 1,
	documentation => 'SAM file with STAR alignments.',
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
	
	warn "Starting job: cleanup_alignment\n";
	
	warn "Validating arguments\n" if $self->verbose;
	$self->validate_args();
	
	warn "Keep single copy for multimappers\n" if $self->verbose;
	open (my $IN, '<', $self->sam);
	open (my $OUT, '>', $self->o_prefix.'reads.adtrim.star_Aligned.out.single.sam');
	while (my $line = <$IN>) {
		if ($line !~ /^@/) {
			my $flag = (split(/\t/, $line))[1];
			next if $flag & 256;
			print $OUT $line;
		}
	}
	close $IN;
	close $OUT;
	
	warn "Preparing sort command\n" if $self->verbose;
	my $cmd = join(' ',
		'sort',
		'-k 3,3',
		'-k 4,4n',
		$self->o_prefix.'reads.adtrim.star_Aligned.out.single.sam',
		'>',
		$self->o_prefix.'reads.adtrim.star_Aligned.out.single.sorted.sam',
	);
	
	warn "Creating output path\n" if $self->verbose;
	$self->make_path_for_output_prefix();
	
	warn "Running cutadapt\n" if $self->verbose;
	warn "Command: $cmd\n" if $self->verbose;
	system "$cmd";
}


1;
