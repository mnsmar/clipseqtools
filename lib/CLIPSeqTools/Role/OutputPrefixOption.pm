=head1 NAME

CLIPSeqTools::Role::OutputPrefixOption - Role to enable output prefix option from the command line

=head1 SYNOPSIS

Role to enable output prefix option from the command line

  Defines options.
      -o_prefix <Str>              output path prefix. Script adds an extension to path. If path does not exist it will be created. Default: ./

  Provides methods.
      make_path_for_output_prefix  creates the path for the output prefix if it does not exist. eg foo/bar.txt will create foo/

=cut


package CLIPSeqTools::Role::OutputPrefixOption;


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use Moose::Role;
use File::Path qw(make_path);
use MooseX::App::Role;


#######################################################################
#######################   Command line options   ######################
#######################################################################
option 'o_prefix' => (
	is            => 'rw',
	isa           => 'Str',
	default       => './',
	documentation => 'output path prefix. Program will add an extension to prefix. If path does not exist it will be created.',
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
	my ($self) = @_;
	
	$self->usage_error('Output path prefix is required') if !$self->o_prefix;
}


1;
