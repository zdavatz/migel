{ pkgs, ... }:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = [ pkgs.git pkgs.libyaml ];

  enterShell = ''
    echo This is the devenv shell for migel
    git --version
    ruby --version
  '';

  env.FREEDESKTOP_MIME_TYPES_PATH = "${pkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml";

  # https://devenv.sh/pre-commit-hooks/
  pre-commit.hooks.shellcheck.enable = true;

  languages.ruby.enable = true;

  # uncomment one of the following to lines to define the ruby version
  languages.ruby.versionFile = ./.ruby-version;
  # languages.ruby.package = pkgs.ruby_3_2;

  services.postgres = {
    enable = true;
    package = pkgs.postgresql_12;
    listen_addresses = "0.0.0.0";
    port = 5434;

    initialDatabases = [
      { name = "migel"; }
    ];

    initdbArgs =
      [
        "--locale=C"
        "--encoding=UTF8"
      ];

    initialScript = ''
      create role migel superuser login password null;
      \connect migel;
      \i 22:20-postgresql_database-migel-backup
    '';
  };

}

# bundle install; bundle exec ruby bin/migeld
# using PGversion 12 or greater results in
# pg_attrdef.adsrc does not exist
