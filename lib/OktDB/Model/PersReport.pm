package OktDB::Model::PersReport;
use Mojo::Base 'OktDB::Model::ArtPersReport', -signatures;
use Time::Piece;
use Mojo::Util qw(dumper encode);


sub getData ($self,$pid) {
    my $db = $self->db;
    my $pers = $self->getPers($pid);

    my $ap_array = $db->select('artpersmember', undef,{ 
        artpersmember_pers => $pid 
    },{
        order_by => { -desc => 'artpersmember_start_ts' }
    })->hashes->map(sub($ap) {
        $ap->{start} = localtime($ap->{artpersmember_start_ts})->strftime('%d.%m.%Y') if $ap->{artpersmember_start_ts};
        $ap->{end} = localtime($ap->{artpersmember_end_ts})->strftime('%d.%m.%Y') if $ap->{artpersmember_end_ts};
        my $api = $ap->{artpersmember_artpers};
        return {
            %$ap,
            members => $self->getApMembers($api),
            artPers => $self->getArtPers($api),
            productions => $self->getProductions($api)
        }
    })->to_array;
    my $ret = {
        pers => $pers,
        artPers => $ap_array,
    };
    $ret = $self->latexEncode($ret);
    #$self->log->debug(dumper $ret);
    return $ret;
}

sub getPers ($self,$pid) {
    my $db = $self->db;
    return $db->select('pers',undef,{
        pers_id => $pid
    })->hash;
}
1;