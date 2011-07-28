package Pinto::IndexManager;

# ABSTRACT: Manages the indexes of a Pinto repository

use MooseX::Singleton;
use Moose::Autobox;

use Path::Class;

use Pinto::Util;
use Pinto::Index;

#-----------------------------------------------------------------------------

# VERSION

#-----------------------------------------------------------------------------

=attr mirror_index

Returns the L<Pinto::Index> that represents our copy of the
F<02packages> file from a CPAN mirror (or possibly another Pinto
repository).  This index will include the latest versions of all the
packages on the mirror.

=cut

has 'mirror_index' => (
    is             => 'ro',
    isa            => 'Pinto::Index',
    builder        => '__build_mirror_index',
    init_arg       => undef,
    lazy           => 1,
);

=attr local_index

Returns the L<Pinto::Index> that represents the F<02packages> file for
your local packages.  This index will include only those packages that
you've locally added to the repository.

=cut

has 'local_index'   => (
    is              => 'ro',
    isa             => 'Pinto::Index',
    builder         => '__build_local_index',
    init_arg        => undef,
    lazy            => 1,
);

=attr master_index

Returns the L<Pinto::Index> that is the logical combination of
packages from both the mirror and local indexes.  See the L<"RULES">
section below for information on how the indexes are combined.

=cut

has 'master_index'  => (
    is              => 'ro',
    isa             => 'Pinto::Index',
    builder         => '__build_master_index',
    init_arg        => undef,
    lazy            => 1,
);

#------------------------------------------------------------------------------
# Roles

with qw(Pinto::Role::Configurable Pinto::Role::Loggable);

#------------------------------------------------------------------------------
# Builders

sub __build_mirror_index {
    my ($self) = @_;

    return $self->__build_index(file => '02packages.details.mirror.txt.gz');
}

#------------------------------------------------------------------------------

sub __build_local_index {
    my ($self) = @_;

    return $self->__build_index(file => '02packages.details.local.txt.gz');
}

#------------------------------------------------------------------------------

sub __build_master_index {
    my ($self) = @_;

    return $self->__build_index(file => '02packages.details.txt.gz');
}

#------------------------------------------------------------------------------

sub __build_index {
    my ($self, %args) = @_;

    my $local = $self->config()->get_required('local');
    my $index_file = Path::Class::file($local, 'modules', $args{file});
    $self->logger->debug("Reading index $index_file");

    return Pinto::Index->new(file => $index_file);
}

#------------------------------------------------------------------------------

sub rebuild_master_index {
    my ($self) = @_;


    # Do this first, to kick lazy builders which also causes
    # validation on the configuration.  Then we can log...
    $self->master_index()->clear();

    $self->logger()->debug("Building master index");

    $self->master_index()->add( @{$self->mirror_index()->packages()} );
    $self->master_index()->merge( @{$self->local_index()->packages()} );

    return $self->master_index();
}

#------------------------------------------------------------------------------

sub commit {
    my ($self) = @_;

    $self->local_index->write();
    $self->rebuild_master_index()->write();

    return $self;
}

#------------------------------------------------------------------------------

sub mirrorable_index {
    my ($self) = @_;
    return $self->mirror_index() - $self->local_index();
}

#------------------------------------------------------------------------------

sub remove_package {
    my ($self, %args) = @_;

    my $package = $args{package};

    my @local_removed = $self->local_index()->remove($package);
    $self->logger->debug("Removed $_ from local index") for @local_removed;

    my @master_removed = $self->master_index()->remove($package);
    $self->logger->debug("Removed $_ from master index") for @master_removed;

    # TODO: Sanity check - packages removed from the local and the
    # master indexes should always be the same.

    return sort map {$_->name()} @local_removed;
}

#------------------------------------------------------------------------------

sub local_author_of {
    my ($self, %args) = @_;

    my $package = $args{package};

    my $pkg = $self->local_index()->packages_by_name()->at($package);

    return $pkg ? $pkg->author() : ();
}


#------------------------------------------------------------------------------

sub has_local_file {
    my ($self, %args) = @_;

    my $file   = $args{file};
    my $author = $args{author};

    my $author_dir    = Pinto::Util::directory_for_author($author);
    my $file_in_index = Path::Class::file($author_dir, $file->basename())->as_foreign('Unix');

    my $packages = $self->master_index()->packages_by_file->at($file_in_index);
    return $packages ? $packages->[0]->file() : ();
}

#------------------------------------------------------------------------------

sub add_local_package {
    my ($self, %args) = @_;

    my $file    = $args{file};
    my $name    = $args{name};
    my $version = $args{version};
    my $author  = $args{author};

    my $author_dir    = Pinto::Util::directory_for_author($author);
    my $file_in_index = Path::Class::file($author_dir, $file->basename())->as_foreign('Unix')->stringify();
    my $package = Pinto::Package->new(name => $name, version => $version, file => $file_in_index);

    $self->local_index()->add($package);
    $self->rebuild_master_index();

    return $self;
}

#------------------------------------------------------------------------------

1;

__END__
