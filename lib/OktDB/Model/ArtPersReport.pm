package OktDB::Model::ArtPersReport;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use LaTeX::Driver;
use Time::Piece;
use Mojo::Util qw(dumper encode slugify);
use Mojo::JSON qw(from_json);
use LaTeX::Encode ':all';
has template => sub ($self) {
    Mojo::Template->new(
        vars => 1,
    );
};

has 'app';
has 'log';
has 'db';


# This action will render a template
sub getReportPdf ($self,$api) {
    my $asset = Mojo::Asset::Memory->new;
    my $pdf;
    my $tex = encode('UTF-8',$self->template->render_file(
        $self->app->home->child('templates',slugify(ref $self).'.tex.ep'),
        {
            tmpl => $self->app->home->child('templates'),
            %{$self->getData($api)}
        }
    ));
    $self->log->debug("tex: $tex");
    my $drv = LaTeX::Driver->new( 
        source  => \$tex,
        output  => \$pdf,
        format  => 'pdf'
    );
    $drv->run;
    $self->log->debug(dumper $drv->stats);
    $asset->add_chunk($pdf);
    return $asset;
}

sub latexEncode ($self,$ret) {
    if (ref $ret eq 'ARRAY') {
        for my $i (@$ret) {
            $i = $self->latexEncode($i);
        }
    }
    elsif (ref $ret eq 'HASH') {
        for my $k (keys %$ret) {
            $ret->{$k} = $self->latexEncode($ret->{$k});
        }
    }
    # some action at a distance
    return (defined $ret ? latex_encode($ret) : undef);
}


sub getData ($self,$api) {
   
    my $ret = {
        artPers => $self->getArtPers($api),
        members => $self->getApMembers($api),
        productions => $self->getProductions($api),
    };
    $ret = $self->latexEncode($ret);
    #$self->log->debug(dumper $ret);
    return $ret;
}

sub getApMembers ($self,$api) {
     my $db = $self->db;
    return $db->select(['artpersmember' 
        => [ 'pers', 'pers_id','artpersmember_pers']
    ],undef,{ 
        artpersmember_artpers => $api 
    })->hashes->map(sub($ap) {
        $ap->{artpersmember_start} = localtime($ap->{artpersmember_start_ts})->strftime('%d.%m.%Y') if $ap->{artpersmember_start_ts};
        $ap->{artpersmember_end} = localtime($ap->{artpersmember_end_ts})->strftime('%d.%m.%Y') if $ap->{artpersmember_end_ts};
        return $ap;
    })->to_array;
}

sub getProductions ($self,$api) {
    my $db = $self->db;
    my $productions = $db->select('production',undef,{ 
        production_artpers => $api 
    },{
        order_by => { -desc => 'production_premiere_ts' }
    })->hashes->map(sub ($el) {
        $el->{production_premiere} = localtime(delete $el->{production_premiere_ts})->strftime('%d.%m.%Y')
            if $el->{production_premiere_ts};
        $el->{production_derniere} = localtime(delete $el->{production_derniere_ts})->strftime('%d.%m.%Y')
            if $el->{production_derniere_ts};
        $el->{oktevents} = $db->select([oktevent => 
                [okt => 'okt_id', 'oktevent_okt'],
                [ -left => 'location', 'location_id', 'oktevent_location'],
            ],undef,{ 
                oktevent_production => $el->{production_id} 
            },{
                order_by => { -desc => 'oktevent_start_ts' }
            })->hashes->map(sub ($ev) {
                $ev->{oktevent_start} = localtime(delete $ev->{oktevent_start_ts})->strftime('%d.%m.%Y %H:%M')
                    if $ev->{oktevent_start_ts};
                return $ev;
            })->to_array;
        $el->{events} = $db->select(['event'
            => [ -left => 'location', 'location_id', 'event_location'],
        ],undef,{ 
            event_production => $el->{production_id}
        }, {
            order_by => { -desc => 'event_date_ts' }
        })->hashes->map(sub ($ev) {
            $ev->{event_date} = localtime(delete $ev->{event_date_ts})->strftime('%d.%m.%Y') if $ev->{event_date_ts};
            $ev->{reviews} = $db->select(['review'
                => [ -left => 'cbuser', 'cbuser_id', 'review.review_cbuser']
            ],undef,{
                review_event => $ev->{event_id}
            })->hashes->map(sub ($rev) {
                $rev->{review_comment} = $self->extractComment(delete $rev->{review_comment_json});
                return $rev;
            })->to_array;
            return $ev;
        })->to_array;
        return $el;
    })->to_array;
    #$self->log->debug(dumper $productions);
    return $productions
}

sub extractComment ($self,$json) {
    my $data = from_json($json);
    my @out;
    for my $el (@{$data->{cfg}}) {
        if (my $s = $el->{cfg}{structure}){
            my %lookup;
            for my $el2 (@{$s}) {
                $lookup{$el2->{key}} = $el2->{title};
            }
            push @out, [
                $el->{label} => $lookup{$data->{model}{$el->{key}}},
            ]
        }
        elsif ($el->{widget} eq 'checkBox') {
            if (not $el->{label}){
                $out[-1][1] .= ', '.$el->{set}{label} if $data->{model}{$el->{key}};
            }
            else {
                push @out, [
                    $el->{label} => $el->{set}{label} 
                 ] if $data->{model}{$el->{key}};
            }
        }
        else {
            push @out, [
                $el->{label} => $data->{model}{$el->{key}},
            ]  if defined $data->{model}{$el->{key}};
        }
    }
    return \@out;
}

sub getArtPers ($self,$api) {
    my $db = $self->db;
    my $artPers = $db->query(<<'SQL_END',$api)->hash;
    SELECT artpers.*,
        strftime('%Y',pt.okt_start_ts,'unixepoch','localtime') AS artpers_pt_year, 
        strftime('%Y',ep.okt_start_ts,'unixepoch','localtime') AS artpers_ep_year, 
        pp.pers_given || ' ' || pp.pers_family AS artpers_progteam_name,
        ap.pers_given || ' ' || ap.pers_family AS artpers_agency_pers_name,
        agency_name AS artpers_agency_name,
        strftime('%d.%m.%Y',artpers_start_ts,'unixepoch','localtime') AS artpers_start,
        strftime('%d.%m.%Y',artpers_end_ts,'unixepoch','localtime') AS artpers_end
    FROM artpers
    LEFT JOIN progteam ON artpers_progteam = progteam_id
    LEFT JOIN pers AS pp ON progteam_pers = pp.pers_id
    LEFT JOIN okt AS pt ON artpers_pt_okt = pt.okt_id
    LEFT JOIN okt AS ep ON artpers_ep_okt = ep.okt_id
    LEFT JOIN apprio ON artpers_apprio = apprio_id
    LEFT JOIN agency ON artpers_agency = agency_id
    LEFT JOIN pers AS ap ON artpers_agency_pers = ap.pers_id
    WHERE artpers_id = ?
SQL_END
    my %apfit;
    $db->select('apfit','*',{
        apfit_active => 1
    },{
        order_by => 'apfit_name'
    })->hashes->each(sub {
        $apfit{$_->{apfit_id}} = $_->{apfit_name};
    });
    $artPers->{artpers_apfit} = join ", ", (sort map { $apfit{$_} } 
            keys from_json(delete $artPers->{artpers_apfit_json}||'{}')->%*);
    return $artPers;
}
1;