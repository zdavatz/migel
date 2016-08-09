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

## TEST/COVERAGE

Don't forget to manually call  jobs/update_migel_products_with_report, as this is a job run only twice a year!

We use Travis-CI to run the tests after each push using `bundle exec rake spec`

The coverage output can be found under coverage/index.html.

## Overview of jobs/update_migel_products

lib/migel/util/importer.rb:
* ODDB::Swissindex::SwissindexMigel is used to get list of all migel_id
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
