package App::Pinto::Command::update;

# ABSTRACT: get the latest archives from a CPAN mirror

use strict;
use warnings;

#-----------------------------------------------------------------------------

use base 'App::Pinto::Command';

#------------------------------------------------------------------------------

# VERSION

#------------------------------------------------------------------------------

sub opt_spec {
    return (
        [ 'force'     => 'Force update, even if indexes appear unchanged' ],
        [ 'remote=s'  => 'URL of a CPAN mirror (or another Pinto repository)' ],
    );
}

#------------------------------------------------------------------------------

sub validate_args {
    my ($self, $opts, $args) = @_;
    $self->usage_error("Arguments are not allowed") if @{ $args };
}

#------------------------------------------------------------------------------

sub execute {
    my ($self, $opts, $args) = @_;
    $self->pinto()->update( %{ $opts } );
}

#------------------------------------------------------------------------------

1;

__END__
