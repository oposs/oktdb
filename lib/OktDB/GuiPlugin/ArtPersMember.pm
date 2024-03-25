package OktDB::GuiPlugin::ArtPersMember;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Time::Piece;
=head1 NAME

OktDB::GuiPlugin::ArtPersMember - ArtPersMember Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::ArtPersMember;

=head1 DESCRIPTION

The Table Gui.

=cut


  
=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractTable> plus:

=cut

has formCfg => sub ($self) {
    return [
        {
            key => 'artpers_id',
            widget => 'hiddenText',
        },
    ]
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
            key => 'artpersmember_id',
            sortable => true,
            primary => true
        },
        {
            label => trm('ArtPers'),
            type => 'string',
            width => '6*',
            key => 'artpers_name',
            sortable => true,
            set => {
                required => true,
            }
        },
        {
            label => trm('Pers'),
            type => 'string',
            width => '6*',
            key => 'pers_name',
            sortable => true,
            set => {
                required => true
            }
        },
        {
            label => trm('Start'),
            type => 'string',
            width => '6*',
            key => 'artpersmember_start_ts',
            sortable => true,
        },
        {
            label => trm('End'),
            type => 'string',
            width => '6*',
            key => 'artpersmember_end_ts',
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
            label => trm('Add ArtPersMember'),
            action => 'popup',
            addToContextMenu => false,
            key => 'add',
            popupTitle => trm('New ArtPersMember'),
            set => {
                height => 300,
                width => 500
            },
            backend => {
                plugin => 'ArtPersMemberForm',
                config => {
                    type => 'add'
                }
            }
        },
        {
            label => trm('Edit ArtPersMember'),
            action => 'popup',
            key => 'edit',
            addToContextMenu => true,
            popupTitle => trm('Edit ArtPersMember'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 300,
                width => 500
            },
            backend => {
                plugin => 'ArtPersMemberForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('Remove ArtPersMember'),
            action => 'submitVerify',
            addToContextMenu => true,
            question => trm('Do you really want to delete the selected ArtPersMember? How about just setting an End date?'),
            key => 'delete',
            buttonSet => {
                enabled => false
            },
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{artpersmember_id};
                die mkerror(4992,"You have to select a artpersmember member first")
                    if not $id;
                eval {
                    $self->db->delete('artpersmember',{artpersmember_id => $id});
                };
                if ($@){
                    $self->log->error("remove artpersmember $id: $@");
                    die mkerror(4993,"Failed to remove artpersmember $id");
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
    my $filter =
        $self->config->{mode} eq 'filtered'
        ? { artpersmember_artpers => $args->{parentFormData}{selection}{artpers_id} } : {};
    return $self->db->select('artpersmember','COUNT(*) AS count',$filter)->hash->{count};
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $WHERE =
        $self->config->{mode} eq 'filtered'
        ? 'WHERE artpersmember_artpers = '.int($args->{parentFormData}{selection}{artpers_id}) : '';

    my $SORT = 'ORDER BY artpersmember_id DESC';
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
    SELECT * FROM (
        SELECT 
            artpersmember_id,
            artpers_name,
            pers_given
            || ' ' || pers_family
            AS pers_name,
            artpersmember_start_ts,
            artpersmember_end_ts
        FROM
            artpersmember 
            JOIN artpers ON artpersmember_artpers = artpers_id
            JOIN pers ON artpersmember_pers = pers_id
        $WHERE
    )
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
        $row->{artpersmember_end_ts} = localtime($row->{artpersmember_end_ts})->strftime("%d.%m.%Y") if $row->{artpersmember_end_ts};
        $row->{artpersmember_start_ts} = localtime($row->{artpersmember_start_ts})->strftime("%d.%m.%Y") if $row->{artpersmember_start_ts};
    }
    return $data;
}

sub getAllFieldValues ($self,$args,$current,$options) {
    my $artPersId = $self->config->{mode} eq 'filtered' ?
        $args->{selection}{artpers_id} : undef;
    return {
        artpers_id => $artPersId,
    };
}


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

__END__

=head1 COPYRIGHT

Copyright (c) 2020 by Tobias Oetiker. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2020-07-20 oetiker 0.0 first version

=cut
