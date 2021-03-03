package OktDB::GuiPlugin::Location;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false decode_json);

=head1 NAME

OktDB::GuiPlugin::Location - Location Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::Location;

=head1 DESCRIPTION

The Table Gui.

=cut


=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

=head2 tableCfg


=cut

has tableCfg => sub {
    my $self = shift;
    return [
        {
            label => trm('Id'),
            type => 'number',
            width => '1*',
            key => 'location_id',
            sortable => true,
            primary => true
        },
        {
            label => trm('Name'),
            type => 'string',
            width => '6*',
            key => 'location_name',
            sortable => true,
        },
        {
            label => trm('OKT'),
            type => 'string',
            width => '2*',
            key => 'location_okt',
            sortable => true,
        },
        {
            label => trm('Contact Person'),
            type => 'string',
            width => '6*',
            key => 'location_contactperson',
            sortable => true,
        },
        {
            label => trm('Phone'),
            type => 'string',
            width => '6*',
            key => 'location_phone',
            sortable => true,
        },
        {
            label => trm('Mobile'),
            type => 'string',
            width => '6*',
            key => 'location_mobile',
            sortable => true,
        },
        {
            label => trm('E-Mail'),
            type => 'string',
            width => '6*',
            key => 'location_email',
            sortable => true,
        },
        {
            label => trm('Web'),
            type => 'string',
            width => '6*',
            key => 'location_url',
            sortable => true,
        },
        {
            label => trm('Address'),
            type => 'string',
            width => '6*',
            key => 'location_postaladdress',
            sortable => true,
        },
        {
            label => trm('Note'),
            type => 'string',
            width => '6*',
            key => 'location_note',
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
            label => trm('Add Location'),
            action => 'popup',
            addToContextMenu => false,
            name => 'LocationAddForm',
            popupTitle => trm('New Location'),
            key => 'add',
            set => {
                height => 550,
                width => 500
            },
            backend => {
                plugin => 'LocationForm',
                config => {
                    type => 'add'
                }
            }
        },
        {
            label => trm('Edit Location'),
            action => 'popup',
            key => 'edit',
            addToContextMenu => false,
            name => 'LocationEditForm',
            popupTitle => trm('Edit Location'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 550,
                width => 500
            },
            backend => {
                plugin => 'LocationForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('Delete Location'),
            action => 'submitVerify',
            addToContextMenu => true,
            buttonSet => {
                enabled => false
            },
            key => 'delete',
            question => trm('Do you really want to delete the selected Location. This will only work if there are no Events linked to it.'),
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{location_id};
                die mkerror(4992,"You have to select a location first")
                    if not $id;
                eval {
                    $self->db->delete('location',{location_id => $id});
                };
                if ($@){
                    $self->log->error("remove location $id: $@");
                    die mkerror(4993,"Faild to remove location $id");
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
    return $self->db->select('location','COUNT(*) AS count')->hash->{count};
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my %SORT;
    my $db = $self->db;
    my $dbh = $db->dbh;
    if ( $args->{sortColumn} ){
        %SORT = (
            order_by => {
            $args->{sortDesc} 
                ? '-desc' : 'asc',
            $args->{sortColumn}
            }
        );
    }
    my $data = $db->select('location','*',undef,{
        %SORT,
        limit => $args->{lastRow}-$args->{firstRow}+1,
        offset => $args->{firstRow}
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
