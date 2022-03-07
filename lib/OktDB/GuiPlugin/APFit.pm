package OktDB::GuiPlugin::APFit;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false decode_json);

=head1 NAME

OktDB::GuiPlugin::APFit - APFit Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::APFit;

=head1 DESCRIPTION

The Table Gui.

=cut


=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

has checkAccess => sub ($self) {
    return ($self->SUPER::checkAccess and $self->user->may('reviewcfg'));
};

=head2 tableCfg


=cut

has tableCfg => sub {
    my $self = shift;
    return [
        {
            label => trm('Id'),
            type => 'number',
            width => '1*',
            key => 'apfit_id',
            sortable => true,
            primary => true
        },
        {
            label => trm('Name'),
            type => 'string',
            width => '6*',
            key => 'apfit_name',
            sortable => true,
        },
        {
            label => trm('Active'),
            type => 'string',
            width => '2*',
            key => 'apfit_active',
            sortable => true,
        },
     ]
};

=head2 actionCfg

Only users who can write get any actions presented.

=cut

has actionCfg => sub {
    my $self = shift;

    return [
        {
            label => trm('Add APFit'),
            action => 'popup',
            addToContextMenu => false,
            popupTitle => trm('New APFit'),
            key => 'add',
            set => {
                height => 200,
                width => 500
            },
            backend => {
                plugin => 'APFitForm',
                config => {
                    type => 'add'
                }
            }
        },
        {
            label => trm('Edit APFit'),
            action => 'popup',
            key => 'edit',
            addToContextMenu => false,
            popupTitle => trm('Edit APFit'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 200,
                width => 500
            },
            backend => {
                plugin => 'APFitForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('Delete APFit'),
            action => 'submitVerify',
            addToContextMenu => true,
            buttonSet => {
                enabled => false
            },
            key => 'delete',
            question => trm('Do you really want to delete the selected APFit. This will only work if there are no ArtPers linked to it.'),
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{apfit_id};
                die mkerror(4992,"You have to select an apfit first")
                    if not $id;
                eval {
                    die "apfit $id is still in use\n"
                        if $self->db->select('artpers','arttpers_id',{
                        \"json_extract(artpers_apfit_json,'\$.${id})" => 1
                    })->hash;
                    $self->db->delete('apfit',{apfit_id => $id});
                };
                if ($@){
                    $self->log->error("remove apfit $id: $@");
                    die mkerror(4993,"Failed to remove apfit $id");
                }
                return {
                    action => 'reload',
                };
            }
        }
    ];
};

sub db {
    shift->user->mojoSqlDb;
};

sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    return $self->db->select('apfit','COUNT(*) AS count')->hash->{count};
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my %SORT = (
        order_by => {
            '-desc' => 'apfit_id'
        }
    );
    my $db = $self->db;
    my $dbh = $db->dbh;
    if ( $args->{sortColumn} ){
        %SORT = (
            order_by => { 
                $args->{sortDesc} 
                ? ' -desc' 
                : ' -asc',
                $args->{sortColumn}
            }
        );
    }
    my $data = $db->select('apfit','*',undef,{
        limit => $args->{lastRow}-$args->{firstRow}+1,
        offset => $args->{firstRow},
        %SORT
    })->hashes;
    for my $row (@$data) {
        $row->{_actionSet} = {
            edit => {
                enabled => true,
            },
            delete => {
                enabled => true,
            },
        }
    }
    return $data;
}

1;

__END__

=head1 COPYRIGHT

Copyright (c) 2020 by Tobias Oetiker. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2020-02-21 oetiker 0.0 first version

=cut
