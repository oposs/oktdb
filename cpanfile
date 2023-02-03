requires 'CallBackery', '>= 0.42.5';
requires 'Mojo::SQLite', '>= 3.008';
requires 'SQL::Abstract::Pg';
requires 'Mojolicious', '>=9.22';
requires 'Mojolicious::Plugin::OpenAPI';
requires 'Crypt::ScryptKDF';
requires 'YAML::XS';
requires 'Time::Piece', '>= 1.3401';
requires 'Mojolicious::Plugin::Qooxdoo', '>= 1.0.10';
requires 'LaTeX::Driver', '>= 1.2.0';
requires 'LaTeX::Encode';
on 'develop' => sub {
  requires 'PLS';
};