package OktDB::GuiPlugin::ProgTeam;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Time::Piece;
=head1 NAME

OktDB::GuiPlugin::ProgTeam - ProgTeam Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::ProgTeam;

=head1 DESCRIPTION

The Table Gui.

=cut

has formCfg => sub {
    my $self = shift;
    return [
        {
            key => 'show_current',
            widget => 'checkBox',
            label => trm('Show Current Members'),
        },
    ];
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
            key => 'progteam_id',
            sortable => true,
            primary => true
        },
        {
            label => trm('Person'),
            type => 'string',
            width => '6*',
            key => 'progteam_who',
            sortable => true,
        },
        {
            label => trm('Start'),
            type => 'string',
            width => '6*',
            key => 'progteam_start_ts',
            sortable => true,
        },
        {
            label => trm('End'),
            type => 'string',
            width => '6*',
            key => 'progteam_end_ts',
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
            label => trm('Add Member'),
            action => 'popup',
            addToContextMenu => false,
            key => 'add',
            popupTitle => trm('New ProgTeam'),
            set => {
                height => 250,
                width => 400
            },
            backend => {
                plugin => 'ProgTeamForm',
                config => {
                    type => 'add'
                }
            }
        },
        {
            label => trm('Edit Member'),
            action => 'popup',
            key => 'edit',
            defaultAction => true,
            addToContextMenu => true,
            popupTitle => trm('Edit ProgTeam'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 250,
                width => 400
            },
            backend => {
                plugin => 'ProgTeamForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('Remove Member'),
            action => 'submitVerify',
            addToContextMenu => true,
            question => trm('Do you really want to delete the selected Member from the OKT Program Team? This will only work if there are no other entries referring to that Member. Maybe you would rather edit the end date.'),
            key => 'delete',
            buttonSet => {
                enabled => false
            },
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{progteam_id};
                die mkerror(4992,"You have to select a progteam member first")
                    if not $id;
                eval {
                    $self->db->delete('progteam',{progteam_id => $id});
                };
                if ($@){
                    $self->log->error("remove progteam $id: $@");
                    die mkerror(4993,"Failed to remove progteam member $id");
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

sub WHERE {
    my $self = shift;
    my $args = shift;
    my $where = {};
    if ($args->{formData}{show_current}) {
        push @{$where->{-or}},
            \[ "progteam_end_ts > CAST(? AS INTEGER) ", time],
            [ progteam_end_ts => undef];
    }
    return $where;
}


sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    return $self->db->select('progteam','COUNT(*) AS count',$self->WHERE($args))->hash->{count};
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $SORT = 'progteam_id DESC';
    my $db = $self->db;
    my $dbh = $db->dbh;
    if ( $args->{sortColumn} ){
        $SORT = $dbh->quote_identifier($args->{sortColumn}).(
            $args->{sortDesc} 
            ? ' DESC' 
            : ' ASC' 
        );
    }
    my $sql = SQL::Abstract->new;
    my $WHERE = $self->WHERE($args);
    my ($where,@where_bind) = $sql->where($WHERE,$SORT);
    my $data = $db->query(<<"SQL_END",
    SELECT progteam.*,
    pers_given || ' ' || pers_family as progteam_who 
    FROM progteam
    JOIN pers ON progteam_pers = pers_id
    $where
    LIMIT ? OFFSET ?
SQL_END
       @where_bind,
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
        $row->{progteam_end_ts} = localtime($row->{progteam_end_ts})->strftime("%d.%m.%Y") if $row->{progteam_end_ts};
        $row->{progteam_start_ts} = localtime($row->{progteam_start_ts})->strftime("%d.%m.%Y") if $row->{progteam_start_ts};
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
