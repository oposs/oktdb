package OktDB::GuiPlugin::ArtPers;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false from_json);
use Time::Piece;
use Text::ParseWords;
use OktDB::Model::ArtPersReport;

=head1 NAME

OktDB::GuiPlugin::ArtPers - ArtPers Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::ArtPers;

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
            reloadOnFormReset => false,
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
            key => 'artpers_id',
            sortable => true,
            primary => true
        },
        {
            label => trm('Name'),
            type => 'string',
            width => '6*',
            key => 'artpers_name',
            sortable => true,
        },
        {
            label => trm('Agency'),
            type => 'string',
            width => '6*',
            key => 'artpers_agency_name',
            sortable => false,
        },
        {
            label => trm('Agency Contact'),
            type => 'string',
            width => '6*',
            key => 'artpers_agency_pers_name',
            sortable => false,
        },
        {
            label => trm('Progteam Contact'),
            type => 'string',
            width => '6*',
            key => 'artpers_progteam_name',
            sortable => true,
        },
        {
            label => trm('Priority'),
            type => 'string',
            width => '6*',
            key => 'apprio_name',
            sortable => true,
        },
        {
            label => trm('eMail'),
            type => 'string',
            width => '6*',
            key => 'artpers_email',
            sortable => true,
        },
        {
            label => trm('Web'),
            type => 'string',
            width => '6*',
            key => 'artpers_web',
            sortable => true,
        },
        {
            label => trm('Mobile'),
            type => 'string',
            width => '6*',
            key => 'artpers_mobile',
            sortable => true,
        },
        {
            label => trm('Eignung'),
            type => 'string',
            width => '6*',
            key => 'apfit',
            sortable => false,
        },
        {
            label => trm('Postal Address'),
            type => 'string',
            width => '6*',
            key => 'artpers_postaladdress',
            sortable => true,
        },
        {
            label => trm('Requirements'),
            type => 'string',
            width => '6*',
            key => 'artpers_requirements',
            sortable => true,
        },
        {
            label => trm('Preis'),
            type => 'string',
            width => '3*',
            key => 'artpers_pt_year',
            sortable => true,
        },
        {
            label => trm('Ehrenpreis'),
            type => 'string',
            width => '3*',
            key => 'artpers_ep_year',
            sortable => true,
        },
        {
            label => trm('Note'),
            type => 'string',
            width => '6*',
            key => 'artpers_note',
            sortable => true,
        },
        {
            label => trm('Start'),
            type => 'string',
            width => '6*',
            key => 'artpers_start',
            sortable => true,
        },
                {
            label => trm('End'),
            type => 'string',
            width => '6*',
            key => 'artpers_end',
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
            label => trm('Add ArtPerson'),
            action => 'popup',
            addToContextMenu => false,
            key => 'add',
            popupTitle => trm('New ArtPerson'),
            set => {
                height => 830,
                width => 400
            },
            backend => {
                plugin => 'ArtPersForm',
                config => {
                    type => 'add'
                }
            }
        },
        {
            label => trm('Edit ArtPerson'),
            action => 'popup',
            key => 'edit',
            defaultAction => true,
            addToContextMenu => true,
            popupTitle => trm('Edit ArtPerson'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 830,
                width => 400
            },
            backend => {
                plugin => 'ArtPersForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('Delete ArtPerson'),
            action => 'submitVerify',
            addToContextMenu => true,
            question => trm('Do you really want to delete the selected ArtPerson. This will only work if there are no other entries refering to that ArtPerson. Maybe edit the End Date instead.'),
            key => 'delete',
            buttonSet => {
                enabled => false
            },
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{artpers_id};
                die mkerror(4992,"You have to select a artperson first")
                    if not $id;
                eval {
                    $self->db->delete('artpers',{artpers_id => $id});
                };
                if ($@){
                    $self->log->error("remove artpers $id: $@");
                    die mkerror(4993,"Failed to remove artperson $id");
                }
                return {
                    action => 'reload',
                };
            }
        },
        {
            label => trm('ArtPerson Members'),
            action => 'popup',
            key => 'members',
            defaultAction => false,
            addToContextMenu => true,
            popupTitle => trm('ArtPerson Members'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 750,
                width => 1200
            },
            backend => {
                plugin => 'ArtPersMember',
                config => {
                    mode => 'filtered'
                }
            }
        },
        {
            label => trm('Add Production'),
            action => 'popup',
            addToContextMenu => false,
            key => 'addprod',
            buttonSet => {
                enabled => false
            },
            popupTitle => trm('New Production'),
            set => {
                height => 400,
                width => 500
            },
            backend => {
                plugin => 'ProductionForm',
                config => {
                    type => 'add'
                }
            }
        }, 
        $self->makeExportAction(
            filename => localtime->strftime('artpers-%Y-%m-%d-%H-%M-%S.xlsx')
        ),
        {
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
        },

    ];
};

sub db {
    return shift->user->mojoSqlDb;
};

sub WHERE {
    my $self = shift;
    my $args = shift;
    my $where = {};
    if (my $str = $args->{formData}{search}) {
        chomp($str);
        for my $search (quotewords('\s+', 0, $str)){
            chomp($search);
            my $lsearch = "%${search}%";
            push @{$where->{-and}}, (
                [
                    artpers_name => { -like => $lsearch },
                ]
            )
        }
    }
    return $where;
}

my $SUB_SELECT = <<"SELECT_END";
    SELECT artpers.*,
        strftime('%Y',pt.okt_start_ts,'unixepoch','localtime') AS artpers_pt_year, 
        strftime('%Y',ep.okt_start_ts,'unixepoch','localtime') AS artpers_ep_year, 
        pp.pers_given || ' ' || pp.pers_family AS artpers_progteam_name,
        ap.pers_given || ' ' || ap.pers_family AS artpers_agency_pers_name,
        agency_name AS artpers_agency_name,
        strftime('%d.%m.%Y',artpers_start_ts,'unixepoch','localtime') AS artpers_start,
        strftime('%d.%m.%Y',artpers_end_ts,'unixepoch','localtime') AS artpers_end
    FROM artpers
    LEFT JOIN progteam ON artpers_progteam = progteam_id
    LEFT JOIN pers AS pp ON progteam_pers = pp.pers_id
    LEFT JOIN okt AS pt ON artpers_pt_okt = pt.okt_id
    LEFT JOIN okt AS ep ON artpers_ep_okt = ep.okt_id
    LEFT JOIN apprio ON artpers_apprio = apprio_id
    LEFT JOIN agency ON artpers_agency = agency_id
    LEFT JOIN pers AS ap ON artpers_agency_pers = ap.pers_id
SELECT_END

sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    my $db = $self->db;
    my $WHERE = $self->WHERE($args);
    my $sql = SQL::Abstract->new;
    my ($where,@where_bind) = $sql->where($WHERE);
    return $db->query(<<"SQL_END",@where_bind)->hash->{count};
    SELECT COUNT(*) AS count FROM (
        $SUB_SELECT
    )
    $where
SQL_END
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $SORT = 'artpers_id DESC';
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
    my %apfit;
    $db->select(
        'apfit','*',{
            apfit_active => 1
        },{
            order_by => 'apfit_name'
        })->hashes->each(sub {
            $apfit{$_->{apfit_id}} = $_->{apfit_name};
        });
    for my $row (@$data) {
        $row->{apfit} = join ", ", (sort map { $apfit{$_} } 
            keys from_json($row->{artpers_apfit_json}||'{}')->%*);

        $row->{_actionSet} = {
            edit => {
                enabled => true
            },
            delete => {
                enabled => true,
            },
            members => {
                enabled => true,
            },
            addprod => {
                enabled => true,
            },
            report => {
                enabled => true,
            },
        };
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
