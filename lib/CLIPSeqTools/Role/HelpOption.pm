=head1 NAME

CLIPSeqTools::Role::HelpOption - Role to enable help option from the command line

=head1 SYNOPSIS

Role to enable help option from the command line

  Defines options.
      -h -? --usage --help       print help message

=cut


package CLIPSeqTools::Role::HelpOption;


#######################################################################
#######################   Load External modules   #####################
#######################################################################
use Modern::Perl;
use autodie;
use Moose::Role;


#######################################################################
########################   Interface Methods   ########################
#######################################################################
sub validate_args {
	my ($self) = @_;
	
	if ($self->help_flag) {
		my ($command) = $self->command_names;
		$self->app->execute_command(
			$self->app->prepare_command('help', $command)
		);
		exit;
    }
}


1;
