package OktDB::GuiPlugin::Production;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Time::Piece;
use Text::ParseWords;
=head1 NAME

OktDB::GuiPlugin::Production - Production Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::Production;

=head1 DESCRIPTION

The Table Gui.

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
 
    return [
       
        {
            label => trm('Edit Production'),
            action => 'popup',
            key => 'edit',
            addToContextMenu => true,
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
        },
        {
            label => trm('Add Event'),
            action => 'popup',
            addToContextMenu => true,
            key => 'addevent',
            buttonSet => {
                enabled => false
            },
            popupTitle => trm('New Event'),
            set => {
                height => 500,
                width => 500
            },
            backend => {
                plugin => 'EventForm',
                config => {
                    type => 'add'
                }
            }
        },
         $self->makeExportAction(
             filename => localtime->strftime('production-%Y-%m-%d-%H-%M-%S.xlsx')
         ),
    ];
};

sub db {
    shift->user->mojoSqlDb;
};

my $keyMap = {
    production => 'production_name',
    artpers => 'artpers_name',
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
                        artpers_name => { -like => $lsearch },
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
    production.*,
    artpers_name
FROM
    production 
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
    my $SORT = 'production_id DESC';
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
            addevent => {
                enabled => true,
            }
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
