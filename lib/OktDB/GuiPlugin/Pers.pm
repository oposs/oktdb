package OktDB::GuiPlugin::Pers;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Time::Piece;
use Text::ParseWords;
use OktDB::Model::PersReport;

=head1 NAME

OktDB::GuiPlugin::Pers - Pers Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::Pers;

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
            key => 'show_removed',
            widget => 'checkBox',
            label => trm('Show Removed Entries'),
        },
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
            key => 'pers_id',
            sortable => true,
            primary => true
        },
        {
            label => trm('Given'),
            type => 'string',
            width => '6*',
            key => 'pers_given',
            sortable => true,
        },
        {
            label => trm('Family'),
            type => 'string',
            width => '6*',
            key => 'pers_family',
            sortable => true,
        },
        {
            label => trm('eMail'),
            type => 'string',
            width => '6*',
            key => 'pers_email',
            sortable => true,
        },
        {
            label => trm('Phone'),
            type => 'string',
            width => '6*',
            key => 'pers_phone',
            sortable => true,
        },
        {
            label => trm('Mobile'),
            type => 'string',
            width => '6*',
            key => 'pers_mobile',
            sortable => true,
        },
        {
            label => trm('Postal Address'),
            type => 'string',
            width => '6*',
            key => 'pers_postaladdress',
            sortable => true,
        },
        {
            label => trm('Birthdate'),
            type => 'string',
            width => '6*',
            key => 'pers_birthdate_ts',
            sortable => true,
        },
        
        {
            label => trm('Note'),
            type => 'string',
            width => '6*',
            key => 'pers_note',
            sortable => true,
        },
        {
            label => trm('End'),
            type => 'string',
            width => '6*',
            key => 'pers_end_ts',
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
            label => trm('Add Person'),
            action => 'popup',
            addToContextMenu => false,
            key => 'add',
            popupTitle => trm('New Person'),
            set => {
                height => 600,
                width => 400
            },
            backend => {
                plugin => 'PersForm',
                config => {
                    type => 'add'
                }
            }
        },
        {
            label => trm('Edit Person'),
            action => 'popup',
            key => 'edit',
            addToContextMenu => false,
            popupTitle => trm('Edit Person'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 600,
                width => 400
            },
            backend => {
                plugin => 'PersForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('Delete Person'),
            action => 'submitVerify',
            addToContextMenu => true,
            question => trm('Do you really want to delete the selected Person. This will only work if there are no other entries refering to that person. Maybe edit the End Date instead.'),
            key => 'delete',
            buttonSet => {
                enabled => false
            },
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{pers_id};
                die mkerror(4992,"You have to select a person first")
                    if not $id;
                eval {
                    $self->db->delete('pers',{pers_id => $id});
                };
                if ($@){
                    $self->log->error("remove pers $id: $@");
                    die mkerror(4993,"Failed to remove person $id");
                }
                return {
                    action => 'reload',
                };
            }
        },
        {
            label => trm('Report'),
            action => 'download',
            addToContextMenu => true,
            key => 'report',
            buttonSet => {
                enabled => false
            },
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{pers_id};
                my $rep = OktDB::Model::PersReport->new(
                    app => $self->app,
                    log => $self->log,
                    db => $self->db,
                );
                my $name = lc $id.'-'.$args->{selection}{pers_family};
                $name =~ s/[^_0-9a-z]+/-/g;
                return {
                    asset    => $rep->getReportPdf($id),
                    type     => 'applicaton/pdf',
                    filename => $name.'.pdf',
                }
            }
        },
    ];
};

sub db {
    shift->user->mojoSqlDb;
};

my $keyMap = {
    given => 'pers_given',
    family => 'pers_family',
};

sub WHERE {
    my $self = shift;
    my $args = shift;
    my $where = {};
    if (not $args->{formData}{show_removed}) {
        push @{$where->{-or}},
            [pers_end_ts => undef ],
            \[ "pers_end_ts >= CAST(? AS INTEGER) ", time]
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
                push @{$where->{-and}}, (
                    -or => [
                        pers_family => { -like => $lsearch },
                        pers_given => { -like => $lsearch },
                    ]
                )
            }
        }
    }
    return $where;
}

sub getTableRowCount {
    my $self = shift;
    my $args = shift;
    return $self->db->select('pers',[\'COUNT(*) AS count'],$self->WHERE($args))->hash->{count};
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $SORT = 'pers_id DESC';
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
    #$self->log->debug($where);
    my $data = $db->query(<<"SQL_END",
    SELECT * FROM pers
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
            report => {
                enabled => true,
            },
        };
        for my $key (keys %$row) {
            next unless $key =~ /_ts$/ and $row->{$key};
            $row->{$key} = localtime($row->{$key})->strftime("%d.%m.%Y");
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

 2020-07-20 oetiker 0.0 first version

=cut
