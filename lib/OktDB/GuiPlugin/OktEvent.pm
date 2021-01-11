package OktDB::GuiPlugin::OktEvent;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Time::Piece;
use Text::ParseWords;

=head1 NAME

OktDB::GuiPlugin::OktEvent - OktEvent Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::OktEvent;

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
            key => 'oktevent_id',
            sortable => true,
            primary => true
        },
        {
            label => trm('OKT'),
            type => 'string',
            width => '6*',
            key => 'okt_edition',
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
            label => trm('ArtPers'),
            type => 'string',
            width => '6*',
            key => 'artpers_name',
            sortable => true,
        },
        {
            label => trm('Type'),
            type => 'string',
            width => '6*',
            key => 'oktevent_type',
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
            label => trm('Start'),
            type => 'string',
            width => '6*',
            key => 'oktevent_start_ts',
            sortable => true,
        },
        {
            label => trm('Duration'),
            type => 'string',
            width => '6*',
            key => 'oktevent_duration_s',
            sortable => true,
        },
        {
            label => trm('Note'),
            type => 'string',
            width => '6*',
            key => 'oktevent_note',
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
            label => trm('Add OktEvent'),
            action => 'popup',
            addToContextMenu => false,
            name => 'AddOktEventForm',
            key => 'add',
            popupTitle => trm('New OktEvent'),
            set => {
                height => 500,
                width => 500
            },
            backend => {
                plugin => 'OktEventForm',
                config => {
                    type => 'add'
                }
            }
        },
        {
            label => trm('Edit OktEvent'),
            action => 'popup',
            key => 'edit',
            addToContextMenu => false,
            name => 'EditOktEventForm',
            popupTitle => trm('Edit OktEvent'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 500,
                width => 500
            },
            backend => {
                plugin => 'OktEventForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('Delete OktEvent'),
            action => 'submitVerify',
            addToContextMenu => true,
            question => trm('Do you really want to delete the selected OktEvent?'),
            key => 'delete',
            buttonSet => {
                enabled => false
            },
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{oktevent_id};
                die mkerror(4992,"You have to select a oktevent first")
                    if not $id;
                eval {
                    $self->db->delete('oktevent',{oktevent_id => $id});
                };
                if ($@){
                    $self->log->error("remove oktevent $id: $@");
                    die mkerror(4993,"Failed to remove oktevent $id");
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

my $keyMap = {
    production => 'production_name',
    artpers => 'artpers_name',
    type => 'oktevent_type',
    location => 'location_name',
    date => sub { 
        \["strftime('%d.%m.%Y',oktevent_start_ts,'unixepoch', 'localtime') = ?",shift] 
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
                        okt_edition => { -like => $lsearch },
                        artpers_name => { -like => $lsearch },
                        location_name => { -like => $lsearch },
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
        oktevent_id,
        okt_edition,
        production_title,
        artpers_name,
        oktevent_type,
        location_name,
        oktevent_start_ts, 
        oktevent_duration_s,
        oktevent_note
    FROM oktevent
    JOIN okt ON oktevent_okt = okt_id
    LEFT JOIN location ON oktevent_location = location_id
    JOIN production ON oktevent_production = production_id
    JOIN artpers ON production_artpers = artpers_id

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
            delete => {
                enabled => true,
            },
        };
        $row->{oktevent_start_ts} = localtime($row->{oktevent_start_ts})->strftime("%d.%m.%Y %H:%M") if $row->{oktevent_start_ts};
        $row->{oktevent_duration_s} = gmtime($row->{oktevent_duration_s})->strftime("%H:%M") if $row->{oktevent_duration_s};
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
