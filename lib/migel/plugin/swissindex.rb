#!/usr/bin/env ruby
# encoding: utf-8
# Migel::SwissindexNonpharmaPlugin -- migel -- 10.04.2012 -- yasaka@ywesee.com
# Migel::Util::Swissindex          -- migel -- 07.09.2011 -- mhatakeyama@ywesee.com

require 'migel/ext/swissindex' # for dRuby

module ODDB
  module Swissindex
    class SwissindexNonpharma; end
  end
end

module Migel
  class SwissindexNonpharmaPlugin
    SWISSINDEX_NONPHARMA_URI    = 'druby://localhost:50002'
    SWISSINDEX_NONPHARMA_SERVER = DRbObject.new(nil, SWISSINDEX_NONPHARMA_URI)
    include Migel::Util
    def initialize(migel_codes)
      @migel_codes = migel_codes
    end
    def get_migelid_by_migel_code(migel_code, lang = 'de')
      Migel::Model::Migelid.find_by_migel_code(migel_code)
    end
    def save_all_products(file_name = 'migel_products_de.csv', lang = 'de', estimate = false)
      saved_products = 0
      migel_codes_with_products    = []
      migel_codes_without_products = []
      lang.upcase!
      start_time = Time.now
      total      = @migel_codes.length
      CSV.open(file_name, 'w') do |writer|
        SWISSINDEX_NONPHARMA_SERVER.session(ODDB::Swissindex::SwissindexNonpharma) do |swissindex|
          if swissindex.download_all
            @migel_codes.each_with_index do |migel_code, count|
              product_flag = false
              if migelid = get_migelid_by_migel_code(migel_code)
                migel_code = migelid.migel_code.split('.').join
                table = swissindex.search_migel_table(migel_code, 'MiGelCode', lang)
                unless table.empty?
                  products = table.select{ |record| record[:pharmacode] and record[:article_name] }
                  products.each do |record|
                    writer << [
                      migel_code,
                      record[:pharmacode],
                      record[:ean_code],
                      record[:article_name],
                      record[:companyname],
                      record[:companyean],
                      record[:ppha],
                      record[:ppub],
                      record[:factor],
                      record[:pzr],
                      record[:size],
                      record[:status],
                      record[:datetime],
                      record[:stdate],
                      record[:language],
                    ]
                    saved_products += 1
                    product_flag = true
                  end
                end
              end
              if product_flag
                migel_codes_with_products << migel_code
              else
                migel_codes_without_products << migel_code
              end
              time = estimate_time(start_time, total, count + 1) 
              puts time if estimate
            end
          else
            # pass
          end
          swissindex.cleanup_items
        end # SWISSINDEX_NONPHARMA_SERVER
      end # CSV.open
      return [
        saved_products,
        migel_codes_with_products,
        migel_codes_without_products
      ]
    end
  end
end
