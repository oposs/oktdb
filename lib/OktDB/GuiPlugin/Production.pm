package OktDB::GuiPlugin::Production;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Time::Piece;
=head1 NAME

OktDB::GuiPlugin::Production - Production Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::Production;

=head1 DESCRIPTION

The Table Gui.

=cut

has checkAccess => sub {
    my $self = shift;
    return 0 if $self->user->userId eq '__ROOT';
    return $self->user->may('admin');
};
  
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
            key => 'production_id',
            sortable => true,
            primary => true
        },
        {
            label => trm('ArtPers'),
            type => 'string',
            width => '6*',
            key => 'artpers_name',
            sortable => true,
        },
        {
            label => trm('Titel'),
            type => 'string',
            width => '6*',
            key => 'production_title',
            sortable => true,
        },
        {
            label => trm('Note'),
            type => 'string',
            width => '6*',
            key => 'production_note',
            sortable => true,
        },
        {
            label => trm('Premiere'),
            type => 'string',
            width => '6*',
            key => 'production_premiere_ts',
            sortable => true,
        },
        {
            label => trm('Derniere'),
            type => 'string',
            width => '6*',
            key => 'production_derniere_ts',
            sortable => true,
        },
     ]
};

=head2 actionCfg

Only users who can write get any actions presented.

=cut

has actionCfg => sub {
    my $self = shift;
    return [] if $self->user and not $self->user->may('admin');

    return [
        {
            label => trm('Add Production'),
            action => 'popup',
            addToContextMenu => false,
            name => 'AddProductionForm',
            key => 'add',
            popupTitle => trm('New Production'),
            set => {
                height => 300,
                width => 500
            },
            backend => {
                plugin => 'ProductionForm',
                config => {
                    type => 'add'
                }
            }
        },
        {
            label => trm('Edit Production'),
            action => 'popup',
            key => 'edit',
            addToContextMenu => false,
            name => 'EditProductionForm',
            popupTitle => trm('Edit Production'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 300,
                width => 500
            },
            backend => {
                plugin => 'ProductionForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('Remove Production'),
            action => 'submitVerify',
            addToContextMenu => true,
            question => trm('Do you really want to delete the selected Production? This will only work if there are no other entries refering to that Production.'),
            key => 'delete',
            buttonSet => {
                enabled => false
            },
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{production_id};
                die mkerror(4992,"You have to select a production member first")
                    if not $id;
                eval {
                    $self->db->delete('production',{production_id => $id});
                };
                if ($@){
                    $self->log->error("remove production $id: $@");
                    die mkerror(4993,"Failed to remove production $id");
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
    return $self->db->select('production','COUNT(*) AS count')->hash->{count};
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $SORT = '';
    my $db = $self->db;
    my $dbh = $db->dbh;
    if ( $args->{sortColumn} ){
        $SORT = 'ORDER BY '.$dbh->quote_identifier($args->{sortColumn}).(
            $args->{sortDesc} 
            ? ' DESC' 
            : ' ASC' 
        );
    }
    my $data = $db->query(<<"SQL_END",
    SELECT * FROM (
        SELECT 
            production.*,
            artpers_name
        FROM
            production 
            JOIN artpers ON production_artpers = artpers_id
    )
    $SORT
    LIMIT ? OFFSET ?
SQL_END
       $args->{lastRow}-$args->{firstRow}+1,
       $args->{firstRow},
    )->hashes;
    for my $row (@$data) {
        $row->{_actionSet} = {
            edit => {
                enabled => true
            },
            delete => {
                enabled => true,
            },
        };
        $row->{production_derniere_ts} = localtime($row->{production_derniere_ts})->strftime("%d.%m.%Y") if $row->{production_derniere_ts};
        $row->{production_premiere_ts} = localtime($row->{production_premiere_ts})->strftime("%d.%m.%Y") if $row->{production_premiere_ts};
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

 2020-07-20 oetiker 0.0 first version

=cut
