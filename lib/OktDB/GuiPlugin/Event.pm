package OktDB::GuiPlugin::Event;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Time::Piece;
use Text::ParseWords;

=head1 NAME

OktDB::GuiPlugin::OktEvent - Event Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::Event;

=head1 DESCRIPTION

The Table Gui.

=cut



=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

has formCfg => sub {
    my $self = shift;
    return [
        {
            key => 'search',
            widget => 'text',
            set => {
                width => 300,
                liveUpdate => true,
                placeholder => trm('search words ...'),
            },
        },
    ];
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
            key => 'event_id',
            sortable => true,
            primary => true
        },
        {
            label => trm('Date'),
            type => 'string',
            width => '6*',
            key => 'event_date_ts',
            sortable => true,
        },
        {
            label => trm('Production'),
            type => 'string',
            width => '6*',
            key => 'production_title',
            sortable => true,
        },
        {
            label => trm('Artpers'),
            type => 'string',
            width => '5*',
            key => 'artpers_name',
            sortable => true,
        },
        {
            label => trm('Location'),
            type => 'string',
            width => '6*',
            key => 'location_name',
            sortable => true,
        },
        {
            label => trm('Responsible'),
            type => 'string',
            width => '6*',
            key => 'progteam_name',
            sortable => true,
        },
        {
            label => trm('Tagalong'),
            type => 'string',
            width => '6*',
            key => 'event_tagalong',
            sortable => true,
        },
        {
            label => trm('Note'),
            type => 'string',
            width => '6*',
            key => 'event_note',
            sortable => true,
        }
     ]
};

=head2 actionCfg

Only users who can write get any actions presented.

=cut

has actionCfg => sub {
    my $self = shift;

    return [
        
        {
            label => trm('Edit Event'),
            action => 'popup',
            key => 'edit',
            addToContextMenu => false,
            name => 'EditEventForm',
            popupTitle => trm('Edit Event'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 500,
                width => 500
            },
            backend => {
                plugin => 'EventForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('Delete Event'),
            action => 'submitVerify',
            addToContextMenu => true,
            question => trm('Do you really want to delete the selected Event?'),
            key => 'delete',
            buttonSet => {
                enabled => false
            },
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{event_id};
                die mkerror(4992,"You have to select a event first")
                    if not $id;
                eval {
                    $self->db->delete('event',{event_id => $id});
                };
                if ($@){
                    $self->log->error("remove oktevent $id: $@");
                    die mkerror(4993,"Failed to remove event $id");
                }
                return {
                    action => 'reload',
                };
            }
        },
        {
            label => trm('Add Review'),
            action => 'popup',
            addToContextMenu => true,
            name => 'AddReviewForm',
            key => 'addreview',
            popupTitle => trm('Review'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 500,
                width => 500
            },
            backend => {
                plugin => 'ReviewForm',
                config => {
                    type => 'add'
                }
            }
        },
    ];
};

sub db {
    shift->user->mojoSqlDb;
};

my $keyMap = {
    production => 'production_name',
    location => 'event_location',
    pers => 'progteam_name',
    date => sub { 
        \["strftime('%d.%m.%Y',event_date_ts,'unixepoch', 'localtime') = ?",shift] 
    }
};

sub WHERE {
    my $self = shift;
    my $args = shift;
    my $where = {};
    if (my $str = $args->{formData}{search}) {
        chomp($str);
        for my $search (quotewords('\s+', 0, $str)){
            chomp($search);
            my $match = join('|',keys %$keyMap);
            if ($search =~ m/^($match):(.+)/){
                my $key = $keyMap->{$1};
                push @{$where->{-and}},
                    ref $key eq 'CODE' ?
                    $key->($2) : ($key => $2) 
            }
            else {
                my $lsearch = "%${search}%";
                push @{$where->{-or}}, (
                    [
                        event_location => { -like => $lsearch },
                        artpers_name => { -like => $lsearch },
                        progteam_name => { -like => $lsearch },
                        production_title => { -like => $lsearch },
                    ]
                )
            }
        }
    }
    return $where;
}

my $SUB_SELECT = <<SELECT_END;

    SELECT 
        event_id,
        production_title,
        artpers_name,
        location_name,
        pers_given || ' ' || pers_family as progteam_name,
        event_tagalong,
        event_note,
        event_date_ts
    FROM event
    JOIN production ON event_production = production_id
    LEFT JOIN location ON event_location = location_id
    JOIN artpers ON production_artpers = artpers_id
    JOIN progteam ON event_progteam = progteam_id
    JOIN pers ON progteam_pers = pers_id

SELECT_END

sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    my $WHERE = $self->WHERE($args);
    my $sql = SQL::Abstract->new;
    my $db = $self->db;
    my ($where,@where_bind) = $sql->where($WHERE);
    return $db->query(<<"SQL_END",@where_bind)->hash->{count};
    SELECT COUNT(*) AS count FROM ( $SUB_SELECT )
    $where
SQL_END
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $SORT = '';
    my $db = $self->db;
    my $dbh = $db->dbh;
    my $sql = SQL::Abstract->new;
    if ( $args->{sortColumn} ){
        $SORT = $dbh->quote_identifier($args->{sortColumn}).(
            $args->{sortDesc} 
            ? ' DESC' 
            : ' ASC' 
        );
    }
    my $WHERE = $self->WHERE($args);
    my ($where,@where_bind) = $sql->where($WHERE,$SORT);
    my $data = $db->query(<<"SQL_END",
    SELECT * FROM ( $SUB_SELECT )
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
            addreview => {
                enabled => true
            },
            delete => {
                enabled => true,
            },
        };
        $row->{event_date_ts} = localtime($row->{event_date_ts})->strftime("%d.%m.%Y %H:%M") if $row->{event_date_ts};
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
