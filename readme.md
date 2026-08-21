# migel

* https://github.com/zdavatz/migel

## DESCRIPTION:

migel gem for ch.oddb.org

## FEATURES/PROBLEMS:

## REQUIREMENTS:

Ruby 3.2 or later. Use bundler to install all dependencies mentioned in the Gemfile

* bundle install

### odba

odba must be at least 1.2.0. Two fixes in it matter here:

* **Reconnecting after the database server restarts.** ydbd-pg reports a lost
  connection as `DBI::ProgrammingError`, which `ODBA::ConnectionPool` used to
  exclude from its retry. A PostgreSQL restart left every pooled connection
  broken for good, and migel search failed with `PQsocket() can't get socket
  descriptor` until `migeld` was restarted by hand.
* **`WITH OIDS` removed** from `CREATE TABLE`, which PostgreSQL 12 and later
  reject.

odba 1.2.0 also deletes `odba/18_19_loading_compatibility`, which migel still
needs, so it is vendored as `lib/migel/loading_compatibility.rb`. It lets Marshal
load `Date` and `Encoding::Character::UTF8` objects written under Ruby 1.8.
`lib/migel/util/server.rb` requires it, so removing it stops `bin/migeld` from
starting.

## INSTALL:

* sudo gem install migel

### Non standard path of postgres

If you have a non standard path of postgres use something like

    gem install pg -- ---with-pg-config=/usr/local/pg-10_1/bin/pg_config

Or if you are using bundler

    bundle config build.pg ----with-pg-config=/usr/local/pg-10_1/bin/pg_config
    bundle install

## TEST/COVERAGE

Don't forget to manually call  jobs/update_migel_products_with_report, as this is a job run only twice a year!

GitHub Actions runs the tests on each push using `bundle exec rake spec`, across Ruby 3.2, 3.3 and 3.4. See `.github/workflows/ruby.yml`. (The `.travis.yml` left in the tree is dead - Travis-CI is no longer used.)

The coverage output can be found under coverage/index.html.

## Overview of jobs/update_migel_products

jobs/update_migel calls update_all in
lib/migel/util/importer.rb:
* ODDB::Swissindex::SwissindexMigel is used to get list of all migel_id
  MiGeL.xls downloaded from https://github.com/zdavatz/oddb2xml_files/raw/master/MiGeL.xls
* save_all_products
** saves /migel_products_de.csv.
** For each migel_id search_migel_table is called.
** SwissindexMigel.search_migel_table 010101001 query_key  MiGelCode lang IT
*** ext/swissindex/src/swissindex.rb calls ODDB::Swissindex::SwissindexMigel
**** calls RefdataArticle.get_refdata is called to get EAN/GTIN (Hash)


## DEVELOPERS:

* Masaomi Hatakeyama
* Yasuhiro Asaka
* Zeno Davatz
* Niklaus Giger

## LICENSE:

* GPLv2
