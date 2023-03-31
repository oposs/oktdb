requires 'CallBackery', '>= 0.45.0';
requires 'Mojolicious', '>= 9.31';
requires 'Mojo::SQLite';
requires 'Mojolicious::Plugin::OpenAPI';
requires 'Crypt::ScryptKDF';
requires 'YAML::XS';
requires 'Time::Piece', '>= 1.3401';
requires 'LaTeX::Driver', '>= 1.2.0';
requires 'LaTeX::Encode';
on 'develop' => sub {
  requires 'PLS';
};