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



=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

has formCfg => sub {
    my $self = shift;
    return [] if $self->config->{mode} =~ /filtered/;
    return [
        {
            key => 'search',
            widget => 'text',
            reloadOnFormReset => false,
            set => {
                width => 300,
                liveUpdate => true,
                placeholder => trm('search words ...'),
            },
        },
    ];
};

has grammar => sub ($self) {
    $self->mergeGrammar(
        $self->SUPER::grammar,
        {
            _vars => [ qw(mode) ],
            type => {
                _doc => 'filtered or full',
                _re => '(filtered|full)',
                _default => 'full'
            }
        },
    );
};
1;

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
        ($self->config->{mode} ne 'filtered-okt' ?
        ({
            label => trm('OKT'),
            type => 'string',
            width => '6*',
            key => 'okt_edition',
            sortable => true,
        }):()),
        {
            label => trm('Production'),
            type => 'string',
            width => '6*',
            key => 'production_title',
            sortable => true,
        },
        ($self->config->{mode} ne 'filtered' ?
        ({
            label => trm('ArtPers'),
            type => 'string',
            width => '6*',
            key => 'artpers_name',
            sortable => true,
        }) : ()),
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
    my @actions;
    
    push @actions, 
        ( {
            label => trm('Add OktEvent'),
            action => 'popup',
            addToContextMenu => false,
            key => 'add',
            popupTitle => trm('New OktEvent'),
            set => {
                height => 700,
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
            addToContextMenu => true,
            popupTitle => trm('Edit OktEvent'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 700,
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
        },
         $self->makeExportAction(
             filename => localtime->strftime('oktevent-%Y-%m-%d-%H-%M-%S.xlsx')
        ) ) if not $self->user or $self->user->may('oktadmin');

        push @actions, {
            label => trm('View OktEvent'),
            action => 'popup',
            key => 'view',
            addToContextMenu => true,
            popupTitle => trm('View OktEvent'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 700,
                width => 500
            },
            backend => {
                plugin => 'OktEventForm',
                config => {
                    type => 'view'
                }
            }
        } if not $self->user or $self->user->may('finance');

        push @actions,{
            label => trm('Open Drive'),
            action => 'submit',
            addToContextMenu => true,
            key => 'drive',
            buttonSet => {
                enabled => false
            },
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $url = $args->{selection}{oktevent_drive_url};
                if ($url) {
                    return {
                        action => 'openLink',
                        url => $url,
                        target => '_blank',
                        features => 'noopener,noreferrer'
                    }
                }
                else {
                    die mkerror(4994,"No Drive URL found for this event");
                }
            }
        };

        push @actions,{
            label => trm('Report'),
            action => 'display',
            addToContextMenu => true,
            key => 'report',
            buttonSet => {
                enabled => false
            },
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{artpers_id};
                my $rep = OktDB::Model::ArtPersReport->new(
                    app => $self->app,
                    log => $self->log,
                    db => $self->db,
                );
                my $name = lc $id.'-'.$args->{selection}{artpers_name};
                $name =~ s/[^_0-9a-z]+/-/g;
                return {
                    asset    => $rep->getReportHtml($id),
                    type     => 'text/html',
                    filename => $name.'.html',
                }
            }
        };

    return \@actions;
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
    if ($self->config->{mode} eq 'filtered') {
        $where->{production_artpers} = $args->{parentFormData}{selection}{artpers_id};
        return $where;
    }if ($self->config->{mode} eq 'filtered-okt') {
        $where->{oktevent_okt} = $args->{parentFormData}{selection}{okt_id};
        return $where;
    }

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
        oktevent_okt,
        okt_edition,
        production_title,
        artpers_name,
        artpers_id,
        oktevent_type,
        location_name,
        oktevent_start_ts, 
        oktevent_duration_s,
        oktevent_note,
        oktevent_drive_url,
        production_artpers
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
    SELECT COUNT(*) AS count FROM ( $SUB_SELECT ) $where
SQL_END
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $SORT = 'oktevent_id DESC';
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
            $self->user->may('finance') ? (view => {
                enabled => true
            }):(),
            $self->user->may('oktadmin') ? (
                edit => {
                    enabled => true
                },
                delete => {
                    enabled => true
                },
            ):(),
            report => {
                enabled => true,
            },
            drive => {
                enabled => $row->{oktevent_drive_url} ? true : false,
            }
        };
        $row->{oktevent_start_ts} = localtime($row->{oktevent_start_ts})->strftime("%d.%m.%Y %H:%M") if $row->{oktevent_start_ts};
        $row->{oktevent_duration_s} = gmtime($row->{oktevent_duration_s})->strftime("%H:%M") if $row->{oktevent_duration_s};
    }
    return $data;
}

sub getAllFieldValues ($self,$args,$extra,$locale){
    return {};
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
