package OktDB::GuiPlugin::LocationForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm';
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);

=head1 NAME

OktDB::GuiPlugin::LocationForm - Edit Form

=head1 SYNOPSIS

 use OktDB::GuiPlugin::LocationForm;

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
    my $db = $self->user->db;

    return [
        $self->config->{type} eq 'edit' ? {
            key => 'location_id',
            label => trm('Id'),
            widget => 'hiddenText',
            set => {
                readOnly => true,
            },
        } : (),
        {
            key => 'location_name',
            label => trm('Name'),
            widget => 'text',
            set => {
                required => true,
            },
        },
        {
            key => 'location_okt',
            label => '',
            widget => 'checkBox',
            set => {
                label => trm('OKT Location'),
            },
        },
        {
            key => 'location_contactpers',
            label => trm('Contact Person'),
            widget => 'text',
            
        },
        {
            key => 'location_phone',
            label => trm('Contact Phone'),
            widget => 'text',
            
        },
        {
            key => 'location_mobile',
            label => trm('Contact Mobile'),
            widget => 'text',
            
        },
        {
            key => 'location_email',
            label => trm('Contact E-Mail'),
            widget => 'text',
            
        },
        {
            key => 'location_url',
            label => trm('Website'),
            widget => 'text',
            
        },
        {
            key => 'location_postaladdress',
            label => trm('Address'),
            widget => 'textArea',
            set => {
                placeholder => trm("Street No\nZIP Town")
            }
        },
        {
            key => 'location_note',
            label => trm('Note'),
            widget => 'textArea',
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
        my $data = {
                map { "location_".$_ => $args->{"location_".$_} } qw(
                    name contactpers okt phone mobile email url postaladdress note
                )
            };
        if ($type eq 'add')  {
            $metaInfo{recId} = $self->db->insert('location',$data)->last_insert_id;
        }
        else {
            $self->db->update('location', $data,{ 
                location_id => $args->{location_id}});
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
               : trm('Add Location'),
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
    return {} if $self->config->{type} ne 'edit';
    my $id = $args->{selection}{location_id};
    return {} unless $id;

    my $db = $self->db;
    my $data = $db->select('location','*'
        ,{location_id => $id})->hash;
    return $data;
}


1;
__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2020-02-21 oetiker 0.0 first version

=cut
