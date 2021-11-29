package OktDB::GuiPlugin::Agency;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Time::Piece;
use Text::ParseWords;
=head1 NAME

OktDB::GuiPlugin::Agency - Agency Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::Agency;

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
            key => 'agency_id',
            sortable => true,
            primary => true
        },
        {
            label => trm('Name'),
            type => 'string',
            width => '6*',
            key => 'agency_name',
            sortable => true,
        },
        {
            label => trm('eMail'),
            type => 'string',
            width => '6*',
            key => 'agency_email',
            sortable => true,
        },
        {
            label => trm('Phone'),
            type => 'string',
            width => '6*',
            key => 'agency_phone',
            sortable => true,
        },
        {
            label => trm('Mobile'),
            type => 'string',
            width => '6*',
            key => 'agency_mobile',
            sortable => true,
        },
        {
            label => trm('Web'),
            type => 'string',
            width => '6*',
            key => 'agency_web',
            sortable => true,
        },
        {
            label => trm('Postal Address'),
            type => 'string',
            width => '6*',
            key => 'agency_postaladdress',
            sortable => true,
        },
        {
            label => trm('Note'),
            type => 'string',
            width => '6*',
            key => 'agency_note',
            sortable => true,
        },
        {
            label => trm('End'),
            type => 'string',
            width => '6*',
            key => 'agency_end_date',
            sortable => false,
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
            label => trm('Add Agency'),
            action => 'popup',
            addToContextMenu => false,
            name => 'AddAgencyForm',
            key => 'add',
            popupTitle => trm('New Agency'),
            set => {
                height => 500,
                width => 400
            },
            backend => {
                plugin => 'AgencyForm',
                config => {
                    type => 'add'
                }
            }
        },
        {
            label => trm('Edit Agency'),
            action => 'popup',
            key => 'edit',
            defaultAction => true,
            addToContextMenu => true,
            name => 'EditAgencyForm',
            popupTitle => trm('Edit Agency'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 500,
                width => 400
            },
            backend => {
                plugin => 'AgencyForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('Delete Agency'),
            action => 'submitVerify',
            addToContextMenu => true,
            question => trm('Do you really want to delete the selected Agency. This will only work if there are no other entries refering to that Agency. Maybe edit the End Date instead.'),
            key => 'delete',
            buttonSet => {
                enabled => false
            },
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{agency_id};
                die mkerror(4992,"You have to select a agency first")
                    if not $id;
                eval {
                    $self->db->delete('agency',{agency_id => $id});
                };
                if ($@){
                    $self->log->error("remove agency $id: $@");
                    die mkerror(4993,"Failed to remove agency $id");
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

    if (my $str = $args->{formData}{search}) {
        chomp($str);
        for my $search (quotewords('\s+', 0, $str)){
            chomp($search);
            my $lsearch = "%${search}%";
            push @{$where->{-and}}, (
                -or => [
                    agency_name => { -like => $lsearch },
                ]
            )
        }
    }
    return $where;
}

sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    return $self->db->select('agency','COUNT(*) AS count',$self->WHERE($args))->hash->{count};
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $sql = SQL::Abstract->new;
    my $SORT = 'agency_id DESC';
    my $db = $self->db;
    my $dbh = $db->dbh;
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
    SELECT * FROM agency
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
        $row->{agency_end_date} = localtime($row->{agency_end_ts})->strftime("%d.%m.%Y") if $row->{agency_end_ts};
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
