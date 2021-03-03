package OktDB::GuiPlugin::ProductionForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Time::Piece;

=head1 NAME

OktDB::GuiPlugin::ProductionForm - Room Edit Form

=head1 SYNOPSIS

 use OktDB::GuiPlugin::ProductionForm;

=head1 DESCRIPTION

The Location Edit Form

=cut


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

    return [
        $self->config->{type} eq 'edit' ? {
            key => 'production_id',
            label => trm('Id'),
            widget => 'hiddenText',
            set => {
                readOnly => true,
            },
        } : (),
        {
            key => 'production_artpers',
            label => trm('ArtPers'),
            widget => 'hiddenText',
            set => {
                readOnly => true
            }
        },
        {
            key => 'artpers_name',
            label => trm('ArtPers'),
            widget => 'text',
            set => {
                readOnly => true
            }
        },
        {
            key => 'production_title',
            label => trm('Title'),
            widget => 'text',
        },
        
        {
            key => 'production_premiere_ts',
            label => trm('Premiere'),
            widget => 'text',
            set => {
                placeholder => trm('dd.mm.yyyy')
            },
            validator => sub ($value,$fieldName,$form) {
                my $t = eval { 
                    localtime->strptime($value,"%d.%m.%Y")->epoch;
                };
                if ($@ or not $t) {
                    return trm('Invalid date');
                }
                $_[0] = $t;
                return "";
            },
        },
        {
            key => 'production_derniere_ts',
            label => trm('Derniere'),
            widget => 'text',
            set => {
                placeholder => trm('dd.mm.yyyy')
            },
            validator => sub ($value,$fieldName,$form) {
                my $t = eval { 
                    localtime->strptime($value,"%d.%m.%Y")->epoch;
                };
                if ($@ or not $t) {
                    return trm('Invalid date');
                }
                $_[0] = $t;
                return "";
            },
        },
        {
            key => 'production_note',
            label => trm('Note'),
            widget => 'textArea',
            set => {
                placeholder => 'Anything noteworthy on that production.'
            }
        },
    ];
};

has actionCfg => sub {
    my $self = shift;
    my $type = $self->config->{type} // 'add';
    
    my $handler = sub {
        my $self = shift;
        my $args = shift;
        my %metaInfo;
        my $fieldMap = { map { 
            "production_".$_ => $args->{"production_".$_} 
            } qw(title artpers premiere_ts derniere_ts note)
        };
        if ($type eq 'add')  {
            $metaInfo{recId} = $self->db->insert('production',$fieldMap)->last_insert_id;
        }
        else {
            $self->db->update('production', $fieldMap,{ production_id => $args->{production_id}});
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
               : trm('Add Production'),
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
        my $pid = $args->{selection}{artpers_id} 
            or die mkerror(3872,"expected artpers_id");
        return $db->select('artpers','artpers_name,artpers_id as production_artpers', {
            artpers_id => $pid
        })->hash;
    }
    return {} if $self->config->{type} ne 'edit';
    my $id = $args->{selection}{production_id};
    return {} unless $id;

    my $data = $db->select(['production' => [ 'artpers', artpers_id => 'production_artpers']],['production.*','artpers_name'],
        ,{production_id => $id})->hash;

    $data->{production_premiere_ts} = localtime
        ->strptime($data->{production_premiere_ts},"%s")
        ->strftime("%d.%m.%Y") 
        if $data->{production_premiere_ts};
    $data->{production_derniere_ts} = localtime
        ->strptime($data->{production_derniere_ts},"%s")
        ->strftime("%d.%m.%Y") 
        if $data->{production_derniere_ts};
    return $data;
}


1;
__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2020-02-21 oetiker 0.0 first version

=cut
