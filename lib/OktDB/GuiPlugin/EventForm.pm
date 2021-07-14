package OktDB::GuiPlugin::EventForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Mojo::Util qw(dumper);
use Time::Piece;
=head1 NAME

OktDB::GuiPlugin::OktEventForm - Room Edit Form

=head1 SYNOPSIS

 use OktDB::GuiPlugin::EventForm;

=head1 DESCRIPTION

The Event Edit Form

=cut


=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractForm> plus:

=cut

sub db {
    shift->user->mojoSqlDb;
}


=head2 formCfg

Returns a Configuration Structure for the Event Entry Form.

=cut



has formCfg => sub {
    my $self = shift;
    my $db = $self->db;
    return [
        $self->config->{type} eq 'edit' ? {
            key => 'event_id',
            label => trm('Id'),
            widget => 'hiddenText',
            set => {
                readOnly => true,
            },
        } : (),
        {
            key => 'event_production',
            label => trm('Id'),
            widget => 'hiddenText',
            set => {
                readOnly => true,
            },
        },
        {
            key => 'production_title',
            label => trm('Production'),
            widget => 'text',
            set => {
                readOnly => true,
            },
           
        },
        {
            key => 'event_location',
            label => trm('Location'),
            widget => 'selectBox',
            set => {
                incrementalSearch => true
            },
            cfg => {
                structure => [
                    { key => undef, title => trm('Select Location') },
                    @{$db->select('location',[
                        [location_id => 'key'],
                        [\"SUBSTR(location_name || COALESCE('; ' || location_postaladdress,''),0,60)" => 'title']
                    ],undef,{
                        order_by => 'location_name'
                    })->hashes->to_array}
                ]
            }
        },
        {
            key => 'event_date_ts',
            label => trm('Date'),
            widget => 'text',
            set => {
                placeholder => trm('dd.mm.yyyy hh:mm'),
                required => true,
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
            key => 'event_progteam',
            label => trm('Leader'),
            widget => 'selectBox',
            set => {
                incrementalSearch => true
            },
            set => {
                required => true,
            },
            cfg => {
                structure => [
                    { key => undef, title => trm('Select Leader') },
                    @{$db->select(
                        \'progteam join pers on progteam_pers = pers_id',
                        [ \"progteam_id AS key",
                          \"pers_family || ' ' || pers_given AS title"],undef,[qw(pers_family)]
                    )->hashes->to_array}
                ]
            }
        },
        {
            key => 'event_tagalong',
            label => trm('Tagalong People'),
            widget => 'textArea',
        },
        {
            key => 'event_note',
            label => trm('Note'),
            widget => 'textArea',
            set => {
                placeholder => 'Anything noteworthy on that event.'
            }
        }
    ];
};

has actionCfg => sub {
    my $self = shift;
    my $type = $self->config->{type} // 'add';
    
    my $handler = sub {
        my $self = shift;
        my $args = shift;
        $self->log->debug(dumper $args);
        my %metaInfo;
        my $fieldMap = { map { 
            "event_".$_ => $args->{'event_'.$_} 
            } qw(date_ts location production progteam tagalong note)
        };
        $self->log->debug(dumper $fieldMap);
        if ($type eq 'add')  {
            $metaInfo{recId} = $self->db->insert('event',$fieldMap)->last_insert_id;
        }
        else {
            $self->db->update('event', $fieldMap,{ event_id => $args->{event_id}});
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
               : trm('Add Event'),
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
    my $db = $self->db;
    if ($self->config->{type} eq 'add') {
        my $pid = $args->{selection}{production_id} 
            or die mkerror(3872,"expected production_id");
        return $db->select('production','production_title,production_id as event_production', {
            production_id => $pid
        })->hash;
    }
    my $id = $args->{selection}{event_id} 
        or die mkerror(9783,"expected event_id");
    my $data = $db->select(\'event join production on event_production = production_id','*',
        ,{event_id => $id})->hash;
    $data->{event_date_ts} = localtime($data->{event_date_ts})
        ->strftime("%d.%m.%Y %H:%M") 
        if $data->{event_date_ts};
    return $data;
}


1;
__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2020-02-21 oetiker 0.0 first version

=cut
