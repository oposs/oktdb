package OktDB::GuiPlugin::OktEventForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Time::Piece;
=head1 NAME

OktDB::GuiPlugin::OktEventForm - Room Edit Form

=head1 SYNOPSIS

 use OktDB::GuiPlugin::OktEventForm;

=head1 DESCRIPTION

The Location Edit Form

=cut


has checkAccess => sub {
    my $self = shift;
    return ($self->user->may('oktadmin') or $self->user->may('finance'));
};


=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractForm> plus:

=cut

sub db {
    shift->user->mojoSqlDb;
}


=head2 formCfg

Returns a Configuration Structure for the Location Entry Form.

=cut



has formCfg => sub {
    my $self = shift;
    my $db = $self->db;
    my %readOnly = ( readOnly => false );
    my %enabled = (
        enabled => true,
    );
    if ($self->config->{type} eq 'view') {
        %readOnly = ( readOnly => true );
        %enabled = (
            enabled => false,
        );
    }
    return [
        $self->config->{type} eq 'edit' ? {
            key => 'oktevent_id',
            label => trm('Id'),
            widget => 'hiddenText',
            set => {
                readOnly => true,
            },
        } : (),
        {
            key => 'oktevent_okt',
            label => trm('Kabarettage'),
            widget => 'selectBox',
            set => {
                incrementalSearch => true,
                %enabled,
            },
            cfg => {
                structure => [
                    { key => undef, title => trm('Select Kabarett-Tage') },
                    @{$db->select(
                        'okt',[\"okt_id AS key",\"okt_edition AS title"],undef,[qw(okt_edition)]
                    )->hashes->to_array}
                ]
            }
        },
        {
            key => 'oktevent_production',
            label => trm('Production'),
            widget => 'selectBox',
            set => {
                incrementalSearch => true,
                %enabled,
            },
            cfg => {
                structure => [
                    { key => undef, title => trm('Select Production') },
                    @{$db->query(<<"SQL_END")->hashes->to_array}
SELECT
    production_id AS key,
    production_title || ' (' || artpers_name || COALESCE(' - ' ||
    strftime('%Y',production_premiere_ts,'unixepoch','localtime'),'') || ')' AS title
FROM production
JOIN artpers ON production_artpers = artpers_id
ORDER BY production_title
SQL_END
                ]
            }
        },
        {
            key => 'oktevent_type',
            label => trm('Type'),
            widget => 'text',
            set => {
                %readOnly,
            }
        },
        {
            key => 'oktevent_location',
            label => trm('Location'),
            widget => 'selectBox',
            set => {
                incrementalSearch => true,
                %enabled,
            },
            cfg => {
                structure => [
                    {
                        key => undef, title => trm('Select Location')    
                    },@{$db->select(
                    'location',[\"location_id AS key",\"location_name as title"],undef,[qw(location_name)]
                )->hashes->to_array}]
            }
        },
        {
            key => 'oktevent_honorarium',
            label => trm('Honorarium'),
            widget => 'text',
            set => {
                %readOnly,
            },
            validator => sub ($value,$fieldName,$form) {
                if ($value ne 0+$value) {
                    return trm("Expected a numeric value");
                }
                return "";
            }
        },
        {
            key => 'oktevent_expense',
            label => trm('Expense'),
            widget => 'text',
            set => {
                %readOnly,
            },
            validator => sub ($value,$fieldName,$form) {
                if ($value ne 0+$value) {
                    return trm("Expected a numeric value");
                }
                return "";
            }
        },
        {
            key => 'oktevent_start_ts',
            label => trm('Start'),
            widget => 'text',
            set => {
                placeholder => trm('dd.mm.yyyy hh:mm'),
                %readOnly
            },
            validator => sub ($value,$fieldName,$form) {
                my $t = eval { 
                    localtime->strptime($value,"%d.%m.%Y %H:%M")->epoch;
                };
                if ($@ or not $t) {
                    return trm('Invalid date');
                }
                $_[0] = $t;
                return "";
            },
        },
        {
            key => 'oktevent_duration_s',
            label => trm('Duration'),
            widget => 'text',
            set => {
                placeholder => trm('hh:mm'),
                %readOnly
            },
            validator => sub ($value,$fieldName,$form) {
                my $t = eval { 
                    gmtime->strptime($value,"%H:%M")->epoch;
                };
                if ($@) {
                    return trm('Invalid date');
                }
                $_[0] = $t;
                return "";
            },
        },
        {
            key => 'oktevent_note',
            label => trm('Note'),
            widget => 'textArea',
            set => {
                %readOnly,
                placeholder => 'Anything noteworthy on that oktevent.'
            }
        }
    ];
};

has actionCfg => sub {
    my $self = shift;
    my $type = $self->config->{type} // 'add';
    return [] if $type eq 'view' or $self->user and not $self->user->may('oktadmin');
    my $handler = sub {
        my $self = shift;
        my $args = shift;
        my %metaInfo;
        my $fieldMap = { map { 
            "oktevent_".$_ => $args->{"oktevent_".$_} 
            } qw(okt production type location expense honorarium start_ts duration_s note)
        };
        if ($self->user->may('oktadmin')) {
            if ($type eq 'add')  {
                $metaInfo{recId} = $self->db->insert('oktevent',$fieldMap)->last_insert_id;
            }
            else {
                $self->db->update('oktevent', $fieldMap,{ oktevent_id => $args->{oktevent_id}});
            }
        }
        else {
            die mkerror(49994,"You are not allowed to edit oktevents.")
        }
        return {
            action => 'dataSaved',
            metaInfo => \%metaInfo
        };
    };

    return [
        {
            label => $type eq 'edit'
               ? trm('Save Changes')
               : trm('Add OktEvent'),
            action => 'submit',
            key => 'save',
            actionHandler => $handler
        }
    ];
};

has grammar => sub {
    my $self = shift;
    $self->mergeGrammar(
        $self->SUPER::grammar,
        {
            _vars => [ qw(type) ],
            type => {
                _doc => 'type of form to show: edit, add',
                _re => '(edit|add)'
            },
        },
    );
};

sub getAllFieldValues {
    my $self = shift;
    my $args = shift;
    return {} if $self->config->{type} eq 'add';
    my $id = $args->{selection}{oktevent_id};
    return {} unless $id;

    my $db = $self->db;
    my $data = $db->select('oktevent','*',
        ,{oktevent_id => $id})->hash;
    $data->{oktevent_duration_s} = gmtime($data->{oktevent_duration_s})->strftime("%H:%M") if $data->{oktevent_duration_s};
    $data->{oktevent_start_ts} = localtime($data->{oktevent_start_ts})
        ->strftime("%d.%m.%Y %H:%M") 
        if $data->{oktevent_start_ts};
    return $data;
}


1;
__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2020-02-21 oetiker 0.0 first version

=cut
