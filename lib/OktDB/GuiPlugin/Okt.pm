package OktDB::GuiPlugin::Okt;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Time::Piece;
=head1 NAME

OktDB::GuiPlugin::Okt - Okt Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::Okt;

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
            key => 'okt_id',
            sortable => true,
            primary => true
        },
        {
            label => trm('Edition'),
            type => 'string',
            width => '6*',
            key => 'okt_edition',
            sortable => true,
        },
        {
            label => trm('Start'),
            type => 'string',
            width => '6*',
            key => 'okt_start_ts',
            sortable => true,
        },
        {
            label => trm('End'),
            type => 'string',
            width => '6*',
            key => 'okt_end_ts',
            sortable => true,
        },
     ]
};

=head2 actionCfg

Only users who can write get any actions presented.

=cut

has actionCfg => sub {
    my $self = shift;
    return [] if $self->user and not $self->user->may('oktadmin');

    return [
        {
            label => trm('Add Okt'),
            action => 'popup',
            addToContextMenu => false,
            key => 'add',
            popupTitle => trm('New Okt'),
            set => {
                height => 240,
                width => 400
            },
            backend => {
                plugin => 'OktForm',
                config => {
                    type => 'add'
                }
            }
        },
        {
            label => trm('Edit Okt'),
            action => 'popup',
            key => 'edit',
            addToContextMenu => true,
            popupTitle => trm('Edit Okt'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 240,
                width => 400
            },
            backend => {
                plugin => 'OktForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('Delete Okt'),
            action => 'submitVerify',
            addToContextMenu => true,
            question => trm('Do you really want to delete the selected Oltner Kabarett-Tage Edition. This will only work if there are no other entries refering to that Edition.'),
            key => 'delete',
            buttonSet => {
                enabled => false
            },
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{okt_id};
                die mkerror(4992,"You have to select a okt first")
                    if not $id;
                eval {
                    $self->db->delete('okt',{okt_id => $id});
                };
                if ($@){
                    $self->log->error("remove okt $id: $@");
                    die mkerror(4993,"Failed to remove okt $id");
                }
                return {
                    action => 'reload',
                };
            }
        },
         $self->makeExportAction(
             filename => localtime->strftime('okt-%Y-%m-%d-%H-%M-%S.xlsx')
         ),
    ];
};

sub db {
    shift->user->mojoSqlDb;
};

sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    return $self->db->select('okt','COUNT(*) AS count')->hash->{count};
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $SORT = 'ORDER BY okt_id DESC';
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
    SELECT * FROM okt
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
        $row->{okt_end_ts} = localtime($row->{okt_end_ts})->strftime("%d.%m.%Y") if $row->{okt_end_ts};
         $row->{okt_start_ts} = localtime($row->{okt_start_ts})->strftime("%d.%m.%Y") if $row->{okt_start_ts};
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
