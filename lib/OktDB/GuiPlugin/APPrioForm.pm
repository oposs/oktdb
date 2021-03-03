package OktDB::GuiPlugin::APPrioForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm';
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);

=head1 NAME

OktDB::GuiPlugin::APPrioForm - Edit Form

=head1 SYNOPSIS

 use OktDB::GuiPlugin::APPrioForm;

=head1 DESCRIPTION

The APPrio Edit Form

=cut


=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractForm> plus:

=cut

has checkAccess => sub ($self) {
    return $self->user->may('reviewcfg');
};

sub db {
    shift->user->mojoSqlDb;
}


=head2 formCfg

Returns a Configuration Structure for the APPrio Entry Form.

=cut



has formCfg => sub {
    my $self = shift;
    my $db = $self->user->db;

    return [
        $self->config->{type} eq 'edit' ? {
            key => 'apprio_id',
            label => trm('Id'),
            widget => 'hiddenText',
            set => {
                readOnly => true,
            },
        } : (),

        {
            key => 'apprio_name',
            label => trm('Name'),
            widget => 'text',
            required => true,
            set => {
                required => true,
            },
        },
        {
            key => 'apprio_active',
            label => trm('Active'),
            widget => 'checkBox',
            set => {
                label => trm('this prio can be selected')
            },
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
                map { "apprio_".$_ => $args->{"apprio_".$_} } qw(
                    name active
                )
            };
        if ($type eq 'add')  {
            $metaInfo{recId} = $self->db->insert('apprio',$data)->last_insert_id;
        }
        else {
            $self->db->update('apprio', $data,{ apprio_id => $args->{apprio_id}});
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
               : trm('Add APPrio'),
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
        apprio_active => 1
    } if $self->config->{type} ne 'edit';
    my $id = $args->{selection}{apprio_id};
    return {} unless $id;

    my $db = $self->db;
    my $data = $db->select('apprio','*'
        ,{apprio_id => $id})->hash;
    return $data;
}


1;
__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2020-02-21 oetiker 0.0 first version

=cut
