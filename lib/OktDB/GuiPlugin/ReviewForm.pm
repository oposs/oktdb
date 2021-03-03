package OktDB::GuiPlugin::ReviewForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm', -signatures;
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false from_json to_json);
use Mojo::Util qw(dumper);
use Time::Piece;
use Carp;

=head1 NAME

OktDB::GuiPlugin::OktEventForm - Room Edit Form

=head1 SYNOPSIS

 use OktDB::GuiPlugin::EventForm;

=head1 DESCRIPTION

The Event Edit Form

=cut


sub db {
    shift->user->mojoSqlDb;
}

=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractForm> plus:

=cut

=head2 formCfg

Returns a Configuration Structure for the Event Entry Form.

=cut


has reviewFormCfg => sub ($self) {
    my $db = $self->db;
    my $entry;
    
    if ($self->config->{type} eq 'add'){
        $entry = from_json($db->select('oktdbcfg','*',{
            oktdbcfg_key => 'reviewFormCfg'
        })->hash->{oktdbcfg_value});
    }
    else {
        my $args = $self->args;
        my $id = $args->{selection}{review_id} 
            // $args->{formData}{review_id}
            // $args->{currentFormData}{review_id};
        if (not $id) {
            $self->log->debug('reviewForm args: '.dumper $self->args);
            confess "only works when selection config is available!";
        }
        my $review = $db->select('review','*',{
            review_id => $id
        })->hash;
        $entry = from_json($review->{review_comment_json})->{cfg};
    }
    return  $entry;
};


has formCfg => sub {
    my $self = shift;
    my $db = $self->db;
    my %readOnly;
    my %enabled;
    if ($self->config->{type} eq 'view') {
        %readOnly = (
            readOnly => true,
        );
        %enabled = (
            enabled => false,
        );
    }
    my @extraCfg;
    for my $cfgIn (@{$self->reviewFormCfg}) {
        my %cfg = %$cfgIn;
        $cfg{key} = 'JSON_'.$cfgIn->{key};
        if ($cfg{widget} eq 'selectBox') {
            $cfg{set} = {
                %{$cfg{set}||{}},
                %enabled
            }
        }
        else {
            $cfg{set} = {
                %{$cfg{set}||{}},
                %readOnly
            };
        }
        push @extraCfg, \%cfg;
    }
    $self->log->debug(dumper \@extraCfg);
    return [
        $self->config->{type} ne 'add' ? {
            key => 'review_id',
            label => trm('Id'),
            widget => 'hiddenText',
            set => {
                readOnly => true,
            },
        } : (),
        {
            key => 'review_event',
            label => trm('Event'),
            widget => 'hiddenText',
            set => {
                readOnly => true,
            },
        },
        {
            key => 'event_info',
            label => trm('Event'),
            widget => 'text',
            set => {
                readOnly => true,
            },
        },
        @extraCfg,
    ];
};

sub getLabel ($self,$cfg,$model) {
    my %label;
    for my $item (@$cfg) {
        next unless $item->{widget} eq 'selectBox';
        my $key = $model->{'JSON_'.$item->{key}};
        for my $row (@{$item->{cfg}{structure}}) {
            next if $row->{key} ne $key;
            $label{$item->{key}} = $row->{title};
            last;
        }
    }
    $self->log->debug(dumper \%label);
    return \%label;
}

has actionCfg => sub {
    my $self = shift;
    return [] unless $self->user;
    my $type = $self->config->{type} or die "type must be configured";
    my $handler = sub {
        my $self = shift;
        my $args = shift;
        $self->args->{selection}{review_id} = $args->{review_id};
        my $reviewFormCfg = $self->reviewFormCfg;
        my %metaInfo;
        my %data;
        for my $entry (@$reviewFormCfg){
            $data{$entry->{key}} = $args->{"JSON_".$entry->{key}};
        };
        
        my $fieldMap = { ( map {
            "review_".$_ => $args->{"review_".$_} 
            } qw(event) ),
            review_comment_json => to_json({
                cfg => $reviewFormCfg,
                model => \%data,
                label => $self->getLabel($reviewFormCfg,$args),
            }),
            review_change_ts => time,
            review_cbuser => $self->user->userId
        };
        if ($type eq 'add')  {
            $metaInfo{recId} = $self->db->insert('review',$fieldMap)->last_insert_id;
        }
        else {
            $self->db->update('review', $fieldMap,{ 
                review_id => $args->{review_id},
                review_cbuser => $self->user->userId
            });

        }
        return {
            action => 'dataSaved',
            metaInfo => \%metaInfo
        };
    };

    return [
        $type ne 'view' ? (
        {
            label => $type eq 'edit'
               ? trm('Save Changes')
               : trm('Add Review'),
            action => 'submit',
            key => 'save',
            actionHandler => $handler
        }
        ) : ()
    ];
};

has grammar => sub {
    my $self = shift;
    $self->mergeGrammar(
        $self->SUPER::grammar,
        {
            _vars => [ qw(type) ],
            type => {
                _doc => 'type of form to show: edit, add, view',
                _re => '(edit|add|view)'
            },
        },
    );
};

sub getAllFieldValues {
    my $self = shift;
    my $args = shift;
    my $db = $self->db;
    if ($self->config->{type} eq 'add') {
        my $pid = $args->{selection}{event_id} 
            or die mkerror(3872,"expected event_id");

        my $data =  $db->select('event',"event_location || ', ' || strftime('%d.%m.%Y %H:%M',event_date_ts,'unixepoch') AS event_info,event_id as review_event", {
            event_id => $pid
        })->hash;
        return $data;
    }
    my $id = $args->{selection}{review_id};
    return {} unless $id;

    my $data = $db->select(\"review join event on review_event = event_id",[\'review.*',\"event_location || ', ' || strftime('%d.%m.%Y %H:%M',event_date_ts,'unixepoch') AS event_info "],{
        review_id => $id
    })->hash;

    $data->{review_change_ts} = localtime($data->{review_change_ts})
        ->strftime("%d.%m.%Y %H:%M") 
        if $data->{review_change_ts};
    my $json = from_json($data->{review_comment_json});
    # $self->log->debug(dumper $json);
    for my $key (keys %{$json->{model}}) {
        $data->{"JSON_".$key} = $json->{model}{$key};
    };
    return $data;
}


1;
__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2021-02-21 oetiker 0.0 first version

=cut
