package OktDB::GuiPlugin::ReviewConfig;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use YAML::XS;
use Mojo::JSON qw(true false decode_json from_json to_json);
use Mojo::Util qw(dumper);
use Time::Piece;
use Encode qw(encode decode);
use JSON::Validator;

=head1 NAME

OktDB::GuiPlugin::ReviewConfig - Configure the Event Review System

=head1 SYNOPSIS

 use OktDB::GuiPlugin::ReviewConfig;

=head1 DESCRIPTION

Event Review Configuration

=cut

has checkAccess => sub ($self) {
    return $self->user->may('reviewcfg');
};

has formValidator => sub ($self) {
    my $validator = JSON::Validator->new;
    $validator->schema({
        '$schema' =>  "http://json-schema.org/draft-07/schema",
        "type" =>  "array",
        "items" =>  {
            "type" =>  "object",
            "additionalProperties" =>  false,
            "required" =>  [
                "key",
                "widget"
            ],
            "properties" =>  {
                "key" =>  {
                    "type" =>  "string"
                },
                "widget" =>  {
                    "type" =>  "string",
                    "enum" =>  [
                        "text",
                        "textArea",
                        "selectBox"
                    ]
                },
                "label" =>  {
                    "type" =>  "string"
                },
                "set" =>  {
                    "type" =>  "object"
                },
                "cfg" =>  {
                    "type" =>  "object"
                }
            }
        }
    });
    return $validator;
};

has tableValidator => sub ($self) {
    my $validator = JSON::Validator->new;
    $validator->schema({
        '$schema' =>  "http://json-schema.org/draft-07/schema",
        "type" =>  "array",
        "items" =>  {
            "type" =>  "object",
            "additionalProperties" => false,
            "required" =>  [
                "label",
                "key",
                "width"
            ],
            "properties" =>  {
                "key" =>  {
                    "type" =>  "string"
                },
                "label" =>  {
                    "type" =>  "string",
                },
                "type" =>  {
                    "type" =>  "string"
                },
                "width" =>  {
                    "type" =>  "string"
                },
            }
        }
    });
    return $validator;
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

    return [
        {
            key => 'reviewFormCfg',
            label => trm('Form Configuration'),
            widget => 'textArea',
            set => {
                height => 400,
            },
            validator => sub ($value,$field,$form) {
                my $data = eval {
                    Load(encode('utf-8',$value));
                };
                if ($@) {
                    return trm("Invalid YAML Syntax");
                }
                if (my @errors = $self->formValidator->validate($data)){
                    return join( "; ", @errors);
                }
                $_[0] = $data;
                return "";
            }
        },
        {
            key => 'reviewTableCfg',
            label => trm('Table Configuration'),
            widget => 'textArea',
            set => {
                height => 400,
            },
            validator => sub ($value,$field,$form) {
                my $data = eval {
                    Load(encode('utf-8',$value));
                };
                if ($@) {
                    return trm("Invalid YAML Syntax");
                }
                if (my @errors = $self->tableValidator->validate($data)){
                    return join( "; ", @errors);
                }
                $_[0] = $data;
                return "";
            }
        }
    ];
};

has actionCfg => sub {
    my $self = shift;
    local $YAML::XS::Boolean = 'JSON::PP';
    my $handler = sub ($self,$args) {
        my $db = $self->db;
        my $tx = $db->begin;
        for my $key (qw(reviewFormCfg reviewTableCfg)) {
            $db->update('oktdbcfg', {
                oktdbcfg_value => to_json($args->{$key})
            }, {
                oktdbcfg_key => $key
            });
        }
        $tx->commit;
        return {
            action => 'dataSaved',
            message => trm("Configuration is updated"),
            title => trm("Updated"),
        };
    };

    return [{
        label => trm('Save Changes'),
        action => 'submit',
        key => 'save',
        actionHandler => $handler
    }];
};


sub getAllFieldValues {
    my $self = shift;
    my $args = shift;
    local $YAML::XS::Boolean = 'JSON::PP';
    my $db = $self->db;
    my %data;
    $db->select('oktdbcfg','*',{
        oktdbcfg_key => ['reviewFormCfg','reviewTableCfg']
    })->hashes->map( sub {
        my $yaml = decode('utf-8',Dump(from_json($_->{oktdbcfg_value})));
        $yaml =~ s/^---\n//;
        $data{$_->{oktdbcfg_key}} = $yaml;
    });
    return \%data;
}


1;
__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2020-02-21 oetiker 0.0 first version

=cut
