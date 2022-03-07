package OktDB::GuiPlugin::APPrio;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false decode_json);

=head1 NAME

OktDB::GuiPlugin::APPrio - APPrio Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::APPrio;

=head1 DESCRIPTION

The Table Gui.

=cut


=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

=head2 tableCfg


=cut
has checkAccess => sub ($self) {
    return ($self->SUPER::checkAccess and $self->user->may('reviewcfg'));
};

has tableCfg => sub {
    my $self = shift;
    return [
        {
            label => trm('Id'),
            type => 'number',
            width => '1*',
            key => 'apprio_id',
            sortable => true,
            primary => true
        },
        {
            label => trm('APPrio Name'),
            type => 'string',
            width => '6*',
            key => 'apprio_name',
            sortable => true,
        },
        {
            label => trm('APPrio Active'),
            type => 'boolean',
            width => '2*',
            key => 'apprio_active',
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
            label => trm('Add APPrio'),
            action => 'popup',
            addToContextMenu => false,
            popupTitle => trm('New APPrio'),
            key => 'add',
            set => {
                height => 200,
                width => 500
            },
            backend => {
                plugin => 'APPrioForm',
                config => {
                    type => 'add'
                }
            }
        },
        {
            label => trm('Edit APPrio'),
            action => 'popup',
            key => 'edit',
            addToContextMenu => false,
            popupTitle => trm('Edit APPrio'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 200,
                width => 500
            },
            backend => {
                plugin => 'APPrioForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('Delete APPrio'),
            action => 'submitVerify',
            addToContextMenu => true,
            buttonSet => {
                enabled => false
            },
            key => 'delete',
            question => trm('Do you really want to delete the selected APPrio. This will only work if there are no Events linked to it.'),
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{apprio_id};
                die mkerror(4992,"You have to select a apprio first")
                    if not $id;
                eval {
                    $self->db->delete('apprio',{apprio_id => $id});
                };
                if ($@){
                    $self->log->error("remove apprio $id: $@");
                    die mkerror(4993,"Faild to remove apprio $id");
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
    return $self->db->select('apprio','COUNT(*) AS count')->hash->{count};
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $SORT = 'ORDER BY apprio_id DESC';
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
    SELECT * FROM apprio
    $SORT
    LIMIT ? OFFSET ?
SQL_END
       $args->{lastRow}-$args->{firstRow}+1,
       $args->{firstRow},
    )->hashes;
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
