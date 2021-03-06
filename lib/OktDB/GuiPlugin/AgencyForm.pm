package OktDB::GuiPlugin::AgencyForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Time::Piece;

=head1 NAME

OktDB::GuiPlugin::AgencyForm - Room Edit Form

=head1 SYNOPSIS

 use OktDB::GuiPlugin::AgencyForm;

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
            key => 'agency_id',
            label => trm('Id'),
            widget => 'hiddenText',
            set => {
                readOnly => true,
            },
        } : (),

        {
            key => 'agency_name',
            label => trm('Agency Name'),
            widget => 'text',
            set => {
                required => true,
            },
        },
        {
            key => 'agency_email',
            label => trm('eMail'),
            widget => 'text',
            validator => sub ($value,$fieldName,$form) {
                return trm('expected user@domain.tld')
                    unless $value =~ /^\S+\@\S+$/;
                return "";                
            },
        },
        {
            key => 'agency_mobile',
            label => trm('Mobile'),
            widget => 'text',
            set => {
                placeholder => '+41 79 443 2222'
            },
            validator => sub ($value,$fieldName,$form) {
                return trm('expected +41 79 ...')
                    unless $value =~ /^\+\d\d[\d\s]+$/;
                return "";
            },
        },
        {
            key => 'agency_phone',
            label => trm('Phone'),
            widget => 'text',
            set => {
                placeholder => '+41 62 123 3422'
            },
            validator => sub ($value,$fieldName,$form) {
                return trm('expected +41 33 ...')
                    unless $value =~ /^\+\d\d[\d\s]+$/;
                return "";
            },
        },
        {
            key => 'agency_web',
            label => trm('Website'),
            widget => 'text',
            set => {
                placeholder => 'https://kabarett.ch'
            },
            validator => sub ($value,$fieldName,$form) {
                return trm('expected http...')
                    unless $value =~ m{^https?://\S+$};
                return "";
            },
        },
        {
            key => 'agency_postaladdress',
            label => trm('Postal Address'),
            widget => 'textArea',
            set => {
                placeholder => "The Strange Master\nBeispielstrass 42\n3432 Example"
            }
        },
        {
            key => 'agency_note',
            label => trm('Note'),
            widget => 'textArea',
            set => {
                placeholder => 'Anything noteworthy on that agency.'
            }
        },
        {
            key => 'agency_end_ts',
            label => trm('End After'),
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
        }
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
                "agency_".$_ => $args->{"agency_".$_} 
            } qw(name email phone mobile web postaladdress note end_ts)
        };

        if ($type eq 'add')  {
            $metaInfo{recId} = $self->db->insert('agency',$fieldMap)->last_insert_id;
        }
        else {
            $self->db->update('agency', $fieldMap,{ agency_id => $args->{agency_id}});
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
               : trm('Add Agency'),
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
    my $id = $args->{selection}{agency_id};
    return {} unless $id;

    my $db = $self->db;
    my $data = $db->select('agency','*',
        ,{agency_id => $id})->hash;
    $data->{agency_end_ts} = localtime
        ->strptime($data->{agency_end_ts},"%s")
        ->strftime("%d.%m.%Y") 
        if $data->{agency_end_ts};
    return $data;
}


1;
__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2020-02-21 oetiker 0.0 first version

=cut
