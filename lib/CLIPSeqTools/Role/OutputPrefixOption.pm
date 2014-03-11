=head1 NAME

CLIPSeqTools::Role::HelpOption - Role to enable output prefix option from the command line

=head1 SYNOPSIS

Role to enable output prefix option from the command line

  Defines options.
      -o_prefix <Str>        output path prefix. Script adds an extension to path. If path does not exist it will be created. Default: ./

=cut


package CLIPSeqTools::Role::OutputPrefixOption;


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use Moose::Role;
use File::Path qw(make_path);


#######################################################################
#######################   Command line options   ######################
#######################################################################
has 'o_prefix' => (
	is            => 'rw',
	isa           => 'Str',
	traits        => ['Getopt'],
	default       => './',
	documentation => 'output path prefix. Script adds an extension to path. If path does not exist it will be created. Default: ./',
);


#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub make_path_for_output_prefix {
	my ($self) = @_;
	
	my (undef, $directory, undef) = File::Spec->splitpath($self->o_prefix);
	make_path($directory);
}

sub validate_args {
	my ($self, $opt, $args) = @_;
	
	$self->usage_error('Output path prefix is required') if !$self->o_prefix;
}


1;
