package OktDB::GuiPlugin::ArtPersForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::Util qw(dumper);
use Mojo::JSON qw(true false to_json from_json);
use Time::Piece;

=head1 NAME

OktDB::GuiPlugin::ArtPersForm - Room Edit Form

=head1 SYNOPSIS

 use OktDB::GuiPlugin::ArtPersForm;

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
    my $args = $self->args;
    my @apFitList;
#    my $activeFit
#    if (%$args) {
#       my $activeFit = decode_json($args->{artpers_apfit_json});
    my $apfitLabel = trm('Eignung');
    $db->select(
        'apfit','*',{
            apfit_active => 1
        },{
            order_by => 'apfit_name'
        })->hashes->each(sub {
            push @apFitList, {
                key => 'artpers_apfit_'.$_->{apfit_id},
                label => $apfitLabel,
                widget => 'checkBox',
                set => {
                    label => $_->{apfit_name}
                }
            };
            $apfitLabel = '';
        });
    return [
        $self->config->{type} eq 'edit' ? {
            key => 'artpers_id',
            label => trm('Id'),
            widget => 'hiddenText',
            set => {
                readOnly => true,
            },
        } : (),

        {
            key => 'artpers_name',
            label => trm('Name'),
            widget => 'text',
            set => {
                required => true,
            },
        },
        {
            key => 'artpers_agency',
            label => trm('Agency'),
            widget => 'selectBox',
            cfg => {
                structure => [
                    { key => undef, title => trm('Select Agency')},
                    @{$db->select(
                    'agency',[\"agency_id AS key",\"agency_name as title"],undef,[qw(agency_name)]
                )->hashes->to_array} ]
            }
        },
        {
            key => 'artpers_agency_pers',
            label => trm('Agency Contact'),
            widget => 'selectBox',
            cfg => {
                structure => [ 
                    { key => undef, title => trm('Select Agency Contact')},
                    @{$db->select(
                    'pers',[\"pers_id AS key",\"pers_given || ' ' || pers_family || coalesce(', ' || pers_email,'') AS title"],undef,[qw(pers_family pers_given)]
                )->hashes->to_array}]
            }
        },
        {
            key => 'artpers_progteam',
            label => trm('ProgTeam Contact'),
            widget => 'selectBox',
            cfg => {
                structure => [ {
                   key => undef, title => trm('Select OKT Person') 
                },@{$db->query(<<"SQL_END")->hashes->to_array}]
                    SELECT progteam_id AS key,
                        pers_family || ', ' || pers_given || coalesce(', ' || pers_email,'') AS title
                    FROM pers JOIN progteam ON progteam_pers = pers_id
                    ORDER by pers_family, pers_given
SQL_END
            }
        },
        {
            key => 'artpers_email',
            label => trm('eMail'),
            widget => 'text',
            validator => sub ($value,$fieldName,$form) {
                return trm('expected user@domain.tld')
                    unless $value =~ /^\S+\@\S+$/;
                return "";                
            },
        },
        {
            key => 'artpers_mobile',
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
            key => 'artpers_phone',
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
            key => 'artpers_postaladdress',
            label => trm('Postal Address'),
            widget => 'textArea',
            set => {
                placeholder => "Maria Muster\nBeispielstrass 42\n3432 Example"
            }
        },
        {
            key => 'artpers_requirements',
            label => trm('Requirements'),
            widget => 'textArea',
            set => {
                placeholder => '50 Green Egs and Ham'
            }
        },
        {
            key => 'artpers_pt_okt',
            label => trm('Kabarettpreis'),
            widget => 'selectBox',
            cfg => {
                structure => [ {
                        key => undef, title => trm('Kein Kabarettpreis'),
                    },@{$db->select(
                    'okt',[\"okt_id AS key", \"strftime('%Y',okt_start_ts,'unixepoch') AS title"],undef,[qw(okt_start_ts)]
                )->hashes->to_array}]
            }
        },
        {
            key => 'artpers_ep_okt',
            label => trm('Ehrenpreis'),
            widget => 'selectBox',
            cfg => {
                structure => [
                    {
                        key => undef, title => trm('Kein Ehrenpreis')
                    },@{$db->select(
                    'okt',[\"okt_id AS key", \"strftime('%Y',okt_start_ts,'unixepoch') AS title"],undef,[qw(okt_start_ts)]
                )->hashes->to_array}]
            }
        },
        {
            key => 'artpers_apprio',
            label => trm('Priority'),
            widget => 'selectBox',
            cfg => {
                structure => [
                    {
                        key => undef, title => trm('No Priority Set')
                    },@{$db->select(
                    'apprio',[\"apprio_id AS key", \"apprio_name AS title"],undef,[{-desc => 'apprio_active'}, 'apprio_name']
                )->hashes->to_array}]
            }
        },
        @apFitList,
        {
            key => 'artpers_note',
            label => trm('Note'),
            widget => 'textArea',
            set => {
                placeholder => 'Anything noteworthy on that artperson.'
            }
        },
        {
            key => 'artpers_start_ts',
            label => trm('Started'),
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
            key => 'artpers_end_ts',
            label => trm('End After'),
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
                "artpers_".$_ => $args->{"artpers_".$_} 
            } qw(name agency agency_pers progteam email web mobile
                postaladdress requirements pt_okt ep_okt note end_ts start_ts)
        };
        my $apfit = {};
        for my $key (%$args) {
            next unless $key =~ m/artpers_apfit_(\d+)/ and $args->{$key};
            $apfit->{$1} = 1;
        }
        $fieldMap->{artpers_apfit_json} = to_json($apfit);
        $self->log->debug("Storing ".dumper $args);
        if ($type eq 'add')  {
            $metaInfo{recId} = $self->db->insert('artpers',$fieldMap)->last_insert_id;
        }
        else {
            $self->db->update('artpers', $fieldMap,{ artpers_id => $args->{artpers_id}});
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
               : trm('Add ArtPers'),
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
    my $id = $args->{selection}{artpers_id};
    return {} unless $id;

    my $db = $self->db;
    my $data = $db->select('artpers','*',
        ,{artpers_id => $id})->hash;
    for (qw(start end)) {
        my $k = "artpers_${_}_ts";
        my $v = $data->{$k};
        $data->{$k} = localtime($v)->strftime("%d.%m.%Y") 
                if $v;
    }
    my $apfit = from_json($data->{artpers_apfit_json}||'{}');
    for my $key (sort keys %$apfit) {
        $data->{'artpers_apfit_'.$key} = true
            if $apfit->{$key};
    }
    return $data;
}


1;
__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2020-02-21 oetiker 0.0 first version

=cut
