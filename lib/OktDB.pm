package OktDB;

use Mojo::Base 'CallBackery', -signatures;
use CallBackery::Model::ConfigJsonSchema;
use Mojo::Util qw(dumper);
use Digest::SHA;
use SQL::Abstract::Pg;

=head1 NAME

OktDB - the application class

=head1 SYNOPSIS

 use Mojolicious::Commands;
 Mojolicious::Commands->start_app('OktDB');

=head1 DESCRIPTION

Configure the mojolicious engine to run our application logic

=cut

=head1 ATTRIBUTES

OktDB has all the attributes of L<CallBackery> plus:

=cut

=head2 config

use our own plugin directory and our own configuration file:

=cut

has config => sub ($self) {
    my $config = CallBackery::Model::ConfigJsonSchema->new(
        app => $self,
        file => $ENV{OKTDB_CONFIG} || $self->home->rel_file('etc/oktdb.yaml')
    );

    unshift @{$config->pluginPath}, __PACKAGE__.'::GuiPlugin';
    return $config;
};


has database => sub ($self) {
    my $database = $self->SUPER::database();
    $database->sql->abstract(
        SQL::Abstract::Pg->new(name_sep => '.', quote_char => '"')
    );
    $database->sql->migrations
        ->name('OktDB')
        ->from_data(__PACKAGE__,'appdb.sql')
        ->migrate;
    return $database;
};

has mailTransport => sub ($self) {
    if ($ENV{HARNESS_ACTIVE}) {
        require Email::Sender::Transport::Test;
        return Email::Sender::Transport::Test->new
    }
    return;
};


sub startup ($self) {
    $self->database;
    return $self->SUPER::startup;
}

1;

=head1 COPYRIGHT

Copyright (c) 2022 by Tobias Oetiker. All rights reserved.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=cut

__DATA__

@@ appdb.sql
-- 1 up

-- people
--sql
CREATE TABLE pers (
    pers_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    pers_given TEXT NOT NULL,
    pers_family TEXT NOT NULL,
    pers_email TEXT,
    pers_mobile TEXT,
    pers_phone TEXT,
    pers_postaladdress TEXT,
    pers_note TEXT,
    pers_end_ts INTEGER
);
-- agencies
--sql
CREATE TABLE agency (
    agency_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    agency_name TEXT NOT NULL,
    agency_email TEXT,
    agency_phone TEXT,
    agency_mobile TEXT,
    agency_web TEXT,
    agency_postaladdress TEXT,
    agency_note TEXT,
    agency_end_ts INTEGER
);

-- oltner kabarett tage
--sql
CREATE TABLE okt (
    okt_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    okt_edition TEXT NOT NULL,
    okt_start_ts INTEGER NOT NULL,
    okt_end_ts INTEGER NOT NULL
);

-- program team
--sql
CREATE TABLE progteam (
    progteam_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    progteam_pers INTEGER NOT NULL REFERENCES pers(pers_id),
    progteam_start_ts INTEGER NOT NULL,
    progteam_end_ts INTEGER
);

-- artist, duo, trio, band, ...
--sql
CREATE TABLE artpers (
    artpers_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    artpers_name TEXT NOT NULL, 
    artpers_agency INTEGER REFERENCES agency(agency_id),
    artpers_agency_pers INTEGER REFERENCES pers(pers_id),
    artpers_progteam INTEGER REFERENCES progteam(progteam_id),
    artpers_email TEXT,
    artpers_web TEXT,
    artpers_mobile TEXT,
    artpers_postaladdress TEXT,
    artpers_requirements TEXT,
    artpers_pt_okt INTEGER REFERENCES okt(okt_id),
    artpers_ep_okt INTEGER REFERENCES okt(okt_id),
    artpers_note TEXT,
    artpers_end_ts INTEGER,
    artpers_start_ts INTEGER
);

-- production
--sql
CREATE TABLE production (
    production_id  INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    production_artpers INTEGER  NOT NULL  REFERENCES artpers(artpers_id),
    production_title TEXT NOT NULL,
    production_premiere_ts INTEGER,
    production_derniere_ts INTEGER
);

-- persons making up an artpers
--sql
CREATE TABLE artpersmember (
    artpersmember_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    artpersmember_pers INTEGER NOT NULL REFERENCES pers(pers_id),
    artpersmember_artpers INTEGER NOT NULL REFERENCES artpers(artpers_id),
    artpersmember_start_ts INTEGER,
    artpersmember_end_ts INTEGER
);

-- location
--sql
CREATE TABLE location (
    location_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    location_name TEXT
);

-- oktevent
--sql
CREATE TABLE oktevent (
    oktevent_id  INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    oktevent_okt INTEGER NOT NULL REFERENCES okt(okt_id),
    oktevent_production INTEGER NOT NULL REFERENCES production(production_id),
    oktevent_type TEXT,
    oktevent_location INTEGER REFERENCES location(location_id),
    oktevent_honorarium REAL,
    oktevent_expense REAL,
    oktevent_start_ts INTEGER,
    oktevent_duration_s INTEGER,
    oktevent_note TEXT
);

-- 2 up

--sql
ALTER TABLE production ADD production_note TEXT;

-- 3 up
--sql

INSERT INTO cbright (cbright_key,cbright_label)
    VALUES 
        ('oktadmin','OKT Admin');

-- 4 up
--sql
CREATE TABLE event (
    event_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    event_production INTEGER NOT NULL 
        REFERENCES production(production_id),
    event_date_ts INTEGER NOT NULL, -- event date
    event_location TEXT NOT NULL,
    event_progteam INTEGER NOT NULL
        REFERENCES  progteam(progteam_id), -- prog team member
    event_tagalong TEXT, -- who joins the excursion
    event_note TEXT
);

--sql
CREATE TABLE review (
    review_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    review_cbuser INTEGER NOT NULL REFERENCES cbuser(cbuser_id),
    review_event INTEGER NOT NULL REFERENCES event(event_id),
    review_change_ts INTEGER NOT NULL,
    review_comment_json TEXT CHECK(json_valid(review_comment_json)) -- structured review
);

--sql
INSERT INTO cbright (cbright_key,cbright_label)
    VALUES 
        ('reviewcfg','Review Cfg');

--sql
CREATE TABLE oktdbcfg (
    oktdbcfg_key TEXT NOT NULL PRIMARY KEY,
    oktdbcfg_descr TEXT NOT NULL,
    oktdbcfg_value TEXT NOT NULL
);

--sql
INSERT INTO oktdbcfg VALUES
    ('reviewFormCfg','Structure of the reviewFormCfg data', '[
  {
    "key": "ein_satz",
    "label": "Ein Satz",
    "widget": "text"
  },
  {
    "key": "impression",
    "label": "Eindruck",
    "widget": "selectBox",
    "cfg": {
      "structure": [
        {
          "key": 10,
          "title": "Haaaaaammmmmer"
        },
        {
          "key": 9,
          "title": "Epochal"
        },
        {
          "key": 1,
          "title": "Naja"
        }
      ]
    }
  },
  {
    "key": "okt_location",
    "label": "Passend für Location",
    "widget": "textArea"
  }
]');

--sql
INSERT INTO oktdbcfg VALUES
    ('reviewTableCfg','Structure of the reviewTableCfg data', '[
  {
    "key": "ein_satz",
    "label": "Ein Satz",
    "width": "1*"
  },
  {
    "key": "impression",
    "label": "Eindruck",
    "width": "1*"
  },
  {
    "key": "okt_location",
    "label": "Passend für Location",
    "width": "1*"
  }
]');

-- 5 up

--sql

ALTER TABLE pers ADD pers_birthdate_ts TEXT;

--sql
CREATE TABLE apfit (
    apfit_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    apfit_name TEXT,
    apfit_active BOOLEAN
);

--sql
CREATE TABLE apprio (
    apprio_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    apprio_name TEXT,
    apprio_active BOOLEAN
);

--sql
ALTER TABLE artpers ADD artpers_apfit_json TEXT CHECK(json_valid(artpers_apfit_json));
--sql
ALTER TABLE artpers ADD artpers_apprio INTEGER REFERENCES apprio(apprio_id);

--sql
ALTER TABLE location ADD location_contactpers TEXT;
ALTER TABLE location ADD location_okt BOOLEAN DEFAULT TRUE;
ALTER TABLE location ADD location_phone TEXT;
ALTER TABLE location ADD location_mobile TEXT;
ALTER TABLE location ADD location_email TEXT;
ALTER TABLE location ADD location_url TEXT;
ALTER TABLE location ADD location_postaladdress TEXT;
ALTER TABLE location ADD location_note TEXT;


CREATE TABLE review_new (
    review_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    review_cbuser INTEGER NOT NULL REFERENCES cbuser(cbuser_id),
    review_event INTEGER NOT NULL REFERENCES event(event_id),
    review_change_ts INTEGER NOT NULL,
    review_comment_json TEXT CHECK(json_valid(review_comment_json)) -- structured review
);
--sql
INSERT INTO review_new SELECT * FROM review;


--sql

CREATE TABLE event_new (
    event_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    event_production INTEGER NOT NULL REFERENCES production(production_id),
    event_date_ts INTEGER NOT NULL, -- event date
    event_location INTEGER REFERENCES location(location_id), -- where will it happen
    event_progteam INTEGER NOT NULL REFERENCES progteam(progteam_id), -- prog team member
    event_tagalong TEXT, -- who joins the excursion
    event_note TEXT
);
--sql

INSERT INTO event_new(
    event_id,event_production,event_date_ts,event_progteam,event_tagalong,event_note) SELECT 
    event_id,event_production,event_date_ts,event_progteam,event_tagalong,event_note FROM event;

-- migrations happen inside a transaction ... and foreign_keys can not
-- be changed inside a transaction ... so we have todo something dangerous
-- https://www.sqlite.org/pragma.html#pragma_foreign_keys

COMMIT;
PRAGMA foreign_keys=off;
DROP TABLE review;
ALTER TABLE review_new RENAME TO review;
DROP TABLE event;
ALTER TABLE event_new RENAME TO event;
PRAGMA foreign_keys=on;
BEGIN;

-- 6 up
--sql

ALTER TABLE artpers ADD artpers_socialmedia_json TEXT 
    CHECK(json_valid(artpers_socialmedia_json));

-- 7 up
--sql


-- make the programteam reference non mandatory
CREATE TABLE event_new (
    event_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    event_production INTEGER NOT NULL REFERENCES production(production_id),
    event_date_ts INTEGER NOT NULL, -- event date
    event_location INTEGER REFERENCES location(location_id), -- where will it happen
    event_progteam INTEGER REFERENCES progteam(progteam_id), -- prog team member
    event_tagalong TEXT, -- who joins the excursion
    event_note TEXT
);
--sql


-- migrations happen inside a transaction ... and foreign_keys can not
-- be changed inside a transaction ... so we have todo something dangerous
-- https://www.sqlite.org/pragma.html#pragma_foreign_keys

COMMIT;
PRAGMA foreign_keys=off;
INSERT INTO event_new SELECT * FROM event;
DROP TABLE event;
ALTER TABLE event_new RENAME TO event;
PRAGMA foreign_keys=on;
BEGIN;

-- 8 up

--sql
INSERT INTO cbright (cbright_key,cbright_label)
    VALUES 
        ('finance','Access Finance Data');
