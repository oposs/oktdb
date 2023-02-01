package OktDB::GuiPlugin::Review;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractTable', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false from_json to_json);
use Time::Piece;
use Text::ParseWords;

=head1 NAME

OktDB::GuiPlugin::Review - Review Table

=head1 SYNOPSIS

 use OktDB::GuiPlugin::Review;

=head1 DESCRIPTION

The Review Table Gui.

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
    my $db = $self->db;
    my $extraCols = from_json($db->select('oktdbcfg','*',{
        oktdbcfg_key => 'reviewTableCfg'
    })->hash->{oktdbcfg_value});
    return [
        {
            label => trm('Id'),
            type => 'number',
            width => '1*',
            key => 'review_id',
            sortable => true,
            primary => true
        },
        {
            label => trm('Production'),
            type => 'string',
            width => '4*',
            key => 'production_title',
            sortable => true,
        },
        {
            label => trm('Artpers'),
            type => 'string',
            width => '4*',
            key => 'artpers_name',
            sortable => true,
        },
        {
            label => trm('Location'),
            type => 'string',
            width => '4*',
            key => 'location_name',
            sortable => true,
        },
        
        {
            label => trm('Reviewer'),
            type => 'string',
            width => '2*',
            key => 'cbuser_name',
            sortable => true,
        },
        (
            map { {   %$_,
                key => "JSON_".$_->{key},
                sortable => false,
            } } @$extraCols,
        ),
        {
            label => trm('Last Update'),
            type => 'string',
            width => '6*',
            key => 'review_change_ts',
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
            label => trm('Edit Review'),
            action => 'popup',
            key => 'edit',
            addToContextMenu => false,
            popupTitle => trm('Edit Review'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 800,
                width => 600
            },
            backend => {
                plugin => 'ReviewForm',
                config => {
                    type => 'edit'
                }
            }
        },
        {
            label => trm('View Review'),
            action => 'popup',
            key => 'view',
            addToContextMenu => false,
            popupTitle => trm('View Review'),
            buttonSet => {
                enabled => false
            },
            set => {
                height => 800,
                width => 600
            },
            backend => {
                plugin => 'ReviewForm',
                config => {
                    type => 'view'
                }
            }
        },
        {
            label => trm('Delete Review'),
            action => 'submitVerify',
            addToContextMenu => true,
            question => trm('Do you really want to delete the selected Review?'),
            key => 'delete',
            buttonSet => {
                enabled => false
            },
            actionHandler => sub {
                my $self = shift;
                my $args = shift;
                my $id = $args->{selection}{review_id};
                die mkerror(4992,"You have to select a review first")
                    if not $id;
                eval {
                    $self->db->delete('review',{
                        review_id => $id,
                        review_cbuser => $self->user->userId
                    });
                };
                if ($@){
                    $self->log->error("remove review $id: $@");
                    die mkerror(4993,"Failed to remove review $id");
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
         $self->makeExportAction(
             filename => localtime->strftime('review-%Y-%m-%d-%H-%M-%S.xlsx')
         ),
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
                my $id = $args->{selection}{artpers_id};
                my $rep = OktDB::Model::ArtPersReport->new(
                    app => $self->app,
                    log => $self->log,
                    db => $self->db,
                );
                my $name = lc $id.'-'.$args->{selection}{artpers_name};
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
    production => 'production_name',
    locaction => 'location_name',
    reviewer => 'cbuser_name'
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
                        location_name => { -like => $lsearch },
                        artpers_name => { -like => $lsearch },
                        cbuser_name => { -like => $lsearch },
                        production_title => { -like => $lsearch },
                        review_comment_json => { -like => $lsearch },
                    ]
                )
            }
        }
    }
    return $where;
}

my $SUB_SELECT = <<SELECT_END;

    SELECT 
        review_id,
        event_id,
        review_change_ts,
        artpers_id,
        production_title,
        artpers_name,
        location_name,
        cbuser_id,
        cbuser_given || ' ' || cbuser_family as cbuser_name,
        event_date_ts,
        review_comment_json
    FROM review
    JOIN event ON review_event = event_id
    LEFT JOIN location ON event_location = location_id
    JOIN production ON event_production = production_id
    JOIN artpers ON production_artpers = artpers_id
    JOIN cbuser ON review_cbuser = cbuser_id

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

sub model2label ($self,$data) {
    for my $cfg (@{$data->{cfg}}){
        $data->{model}{$cfg->{key}} 
            = $data->{label}{$cfg->{key}}
                if $data->{label}{$cfg->{key}};
        
    }
}

sub getTableData {
    my $self = shift;
    my $args = shift;
    my $SORT = 'review_id DESC';
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
    my $tableKeys = {
        map {
            $_->{key} => 1
        } @{$self->tableCfg}
    };
    my $currentUser = $self->user->userId;
    for my $row (@$data) {
        my $ok = $row->{cbuser_id} eq $currentUser;
        $row->{_actionSet} = {
            edit => {
                enabled => $ok ? true : false,
            },
            view => {
                enabled => $ok ? false : true,
            },
            delete => {
                enabled => $ok ? true : false,
            },
            addreview =>{
                enabled => $row->{cbuser_id} ne $currentUser ? true : false,
            },
            report => {
                enabled => true,
            }
        };
        for my $field (keys %$row) {
            $row->{$field} = localtime($row->{$field})
                ->strftime("%d.%m.%Y %H:%M") 
                    if $field =~ /_ts$/ and $row->{$field};
            my $data = from_json($row->{review_comment_json});
            $self->model2label($data);
            for my $key (keys %{$data->{model}}) {
                if ($tableKeys->{'JSON_'.$key} ) {
                    $row->{'JSON_'.$key} = $data->{model}{$key};
                }
            }
        }
    }
    return $data;
}

1;

__END__

=head1 COPYRIGHT

Copyright (c) 2021 by Tobias Oetiker. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2020-07-20 oetiker 0.0 first version

=cut
