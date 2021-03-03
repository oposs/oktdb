package OktDB::GuiPlugin::APFitForm;
use Mojo::Base 'CallBackery::GuiPlugin::AbstractForm';
use CallBackery::Translate qw(trm);
use CallBackery::Exception qw(mkerror);
use Mojo::JSON qw(true false);

=head1 NAME

OktDB::GuiPlugin::APFitForm - Edit Form

=head1 SYNOPSIS

 use OktDB::GuiPlugin::APFitForm;

=head1 DESCRIPTION

The APFit Edit Form

=cut


=head1 METHODS

All the methods of L<CallBackery::GuiPlugin::AbstractForm> plus:

=cut

sub db {
    shift->user->mojoSqlDb;
}
has checkAccess => sub ($self) {
    return $self->user->may('reviewcfg');
};


=head2 formCfg

Returns a Configuration Structure for the APFit Entry Form.

=cut



has formCfg => sub {
    my $self = shift;
    my $db = $self->user->db;

    return [
        $self->config->{type} eq 'edit' ? {
            key => 'apfit_id',
            label => trm('Id'),
            widget => 'hiddenText',
            set => {
                readOnly => true,
            },
        } : (),

        {
            key => 'apfit_name',
            label => trm('Name'),
            widget => 'text',
            set => {
                required => true,
            },
        },
        {
            key => 'apfit_active',
            label => trm('Active'),
            widget => 'checkBox',
            set => {
                label => trm('This fit can be added')
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
                map { 'apfit_'.$_ => $args->{'apfit_'.$_} } qw(
                    name active
                )
            };
        if ($type eq 'add')  {
            $metaInfo{recId} = $self->db->insert('apfit',$data)->last_insert_id;
        }
        else {
            $self->db->update('apfit',$data ,{ apfit_id => $args->{apfit_id}});
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
               : trm('Add APFit'),
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
        apfit_active => 1
    } if $self->config->{type} ne 'edit';
    my $id = $args->{selection}{apfit_id};
    return {} unless $id;

    my $db = $self->db;
    my $data = $db->select('apfit','*'
        ,{apfit_id => $id})->hash;
    return $data;
}


1;
__END__

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2020-02-21 oetiker 0.0 first version

=cut
