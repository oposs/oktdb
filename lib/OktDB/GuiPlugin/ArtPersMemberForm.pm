package OktDB::GuiPlugin::ArtPersMemberForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);
use Time::Piece;

=head1 NAME

OktDB::GuiPlugin::ArtPersMemberForm - Room Edit Form

=head1 SYNOPSIS

 use OktDB::GuiPlugin::ArtPersMemberForm;

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
            key => 'artpersmember_id',
            label => trm('Id'),
            widget => 'hiddenText',
            set => {
                readOnly => true,
            },
        } : (),
        {
            key => 'artpersmember_artpers',
            label => trm('ArtPers'),
            widget => 'hiddenText',
            set => {
                readOnly => true,
            },
        },
        # {
        #     key => 'artpersmember_artpers',
        #     label => trm('ArtPers'),
        #     widget => 'selectBox',
        #     cfg => {
        #         structure => [
        #             { key => undef, title => trm("Select ArtPers") },
        #             @{$db->select(
        #             'artpers',[\"artpers_id AS key",\"artpers_name AS title"],undef,[qw(artpers_name)]
        #         )->hashes->to_array}]
        #     }
        # },
        {
            key => 'artpersmember_pers',
            label => trm('Person'),
            widget => 'selectBox',
            set => {
                incrementalSearch => true
            },
            cfg => {
                structure => [ 
                    { key => undef, title => trm('Select Person')},
                    @{$db->select(
                    'pers',[\"pers_id AS key",\"pers_family || ', ' || pers_given || COALESCE(', ' || pers_email,'') AS title"],undef,[qw(pers_family pers_given)]
                )->hashes->to_array}]
            }
        },
        {
            key => 'artpersmember_start_ts',
            label => trm('Start'),
            widget => 'text',
            set => {
                placeholder => trm('dd.mm.yyyy')
            },
            validator => sub ($value,$fieldName,$form) {
                my $t = eval { 
                    localtime->strptime($value,"%d.%m.%Y")->epoch;;
                };
                if ($@ or not $t) {
                    return trm('Invalid date');
                }
                $_[0] = $t;
                return "";
            },
        },
        {
            key => 'artpersmember_end_ts',
            label => trm('End'),
            widget => 'text',
            set => {
                placeholder => trm('dd.mm.yyyy')
            },
            validator => sub ($value,$fieldName,$form) {
                my $t = eval { 
                    localtime->strptime($value,"%d.%m.%Y")->epoch;;
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
            "artpersmember_".$_ => $args->{"artpersmember_".$_} 
            } qw(pers artpers start_ts end_ts)
        };
        if ($type eq 'add')  {
            $metaInfo{recId} = $self->db->insert('artpersmember',$fieldMap)->last_insert_id;
        }
        else {
            $self->db->update('artpersmember', $fieldMap,{ artpersmember_id => $args->{artpersmember_id}});
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
               : trm('Add ArtPersMember'),
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
    return {
        artpersmember_artpers => $args->{artpers_id}
    } if $self->config->{type} ne 'edit';
    my $id = $args->{selection}{artpersmember_id};
    return {} unless $id;

    my $db = $self->db;
    my $data = $db->select('artpersmember','*',
        ,{artpersmember_id => $id})->hash;
    $data->{artpersmember_start_ts} = localtime
        ->strptime($data->{artpersmember_start_ts},"%s")
        ->strftime("%d.%m.%Y") 
        if $data->{artpersmember_start_ts};
    $data->{artpersmember_end_ts} = localtime
        ->strptime($data->{artpersmember_end_ts},"%s")
        ->strftime("%d.%m.%Y") 
        if $data->{artpersmember_end_ts};
    return $data;
}


1;
__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2020-02-21 oetiker 0.0 first version

=cut
