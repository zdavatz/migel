# migel

* https://github.com/zdavatz/migel

## DESCRIPTION:

migel gem for ch.oddb.org

## FEATURES/PROBLEMS:

## REQUIREMENTS:

Use bundler to install all dependencies mentioned in the Gemfile

* bundle install

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

We use Travis-CI to run the tests after each push using `bundle exec rake spec`

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
