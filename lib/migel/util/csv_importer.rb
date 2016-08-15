#!/usr/bin/env ruby
# encoding: utf-8

# Importer for CSV from Bauerfeind AG

require 'csv'
require 'fileutils'
require 'zlib'
require 'migel/util/mail'
require 'spreadsheet'
require 'open-uri'
require 'migel/util/server'
require 'migel/util/importer'
require 'migel/model/group'
include Migel::Util

module Migel
  module Util
    class CsvImporter
      Status_csv_items = 'A'
      Companyname_DE = 'Bauerfeind AG'
      Companyname_FR = 'Bauerfeind SA'
      attr_reader :data_dir
      attr_reader :csv_file
      def initialize
        $stdout.sync = true
        @nr_updated = 0
        @nr_ignored = 0
        @nr_records = 0
        @nr_products_before = 0
        @nr_products_after = 0
        @migel_codes_with_products = []
        @migel_codes_without_products = []
      end

      def report(lang = 'de')
        lang = lang.downcase
        end_time = Time.now - @start_time
        @update_time = (end_time / 60.0).to_i
        res = [
          "Total time to update: #{"%.2f" % @update_time} [m]",
          sprintf("found via %s or %s were. Active products before/now: %d/%d", Companyname_DE, Companyname_FR, @nr_products_before-@nr_products_after, get_nr_active_bauerfeind_products),
          "Read CSV-file: #{@csv_file}",
          sprintf("Total %5i Migelids (%5i Migelids have products / %5i Migelids have no products)",
                  @nr_records,
                  @migel_codes_with_products    ? @migel_codes_with_products.length : 0,
                  @migel_codes_without_products ? @migel_codes_without_products.length : 0),
          "Saved #{@saved_products} Products",
        ]
        res += [
          '',
          "Migelids with products (#{@migel_codes_with_products ? @migel_codes_with_products.length : 0})"
        ]
        res += @migel_codes_with_products.sort.uniq.map{|migel_code|
          "http://ch.oddb.org/#{lang}/gcc/migel_search/migel_product/#{migel_code}"
        } if @migel_codes_with_products
        res += [
          '',
          "Migelids without products (#{@migel_codes_without_products ? @migel_codes_without_products.length : 0})"
        ]
        res[-1] += @migel_codes_without_products.sort.uniq.map{|migel_code|
          "http://ch.oddb.org/#{lang}/gcc/migel_search/migel_product/#{migel_code}"}.to_s if @migel_codes_without_products and @migel_codes_without_products.size > 0
          subject = res[0]
          Migel::Util::Mail.notify_admins_attached(subject, res, nil)
          res
      end

      def import_all_products_from_csv(options)
        @start_time = Time.now
        puts "#{Time.now}: import_all_products_from_csv: options are #{options}"
        file_name = options[:filename]
        puts "#{Time.now}: import_all_products_file_name are #{file_name.inspect}"
        file_name = '/var/www/migel/data/csv/update_migel_bauerfeind.csv' unless file_name && file_name.length > 0
        unless File.exist?(file_name)
          puts "#{Time.now}: Unable to open #{file_name}"
          return false
        end
        lang = (options[:lang] ||= 'de')
        estimate = (options[:estimate] || false)
        puts "#{Time.now}: import_all_products_from_csv: file_name #{file_name} lang #{lang} estimate #{estimate}"
        @csv_file = File.expand_path(file_name)
        @data_dir = File.dirname(@csv_file)
        FileUtils.mkdir_p @data_dir
        lang.upcase!
        total = File.readlines(file_name).to_a.length
        count = 0
        @nr_products_before = get_nr_active_bauerfeind_products
        set_bauerfeind_products_inactive
        products = Migel::Util::Server.new.all_products
        CSV.foreach(file_name, :col_sep => ';') do |line|
          count += 1
          migel_code = line[5]
          next if /Migel/i.match(migel_code)
          if line[4] == nil || line[4].length == 0
            puts "#{Time.now}: Missing pharmacode in line #{count}: #{line}"
            next
          end
          @nr_records += 1
          ean13 = line[1]
          if migelid = Migel::Model::Migelid.find_by_migel_code(migel_code)
            pharmacode = line[4]
            nr_invalids = migelid.products.find_all{|i| i.pharmacode.to_i == 0}.size
            if nr_invalids > 0
              puts "#{Time.now}: Deactivating non digital pharmacode #{pharmacode} for #{migel_code} found via #{line}"
              migelid.products.delete_if{|i| i.pharmacode.to_i == 0 }
              migelid.save
            end
            with_matching_ean = migelid.products.find_all{|i| i.ean_code == ean13}
            with_matching_pharmacode = migelid.products.find_all{|i| i.pharmacode.to_i != 0 && i.pharmacode == pharmacode}
            record = {
              :ean_code     => ean13,
              :pharmacode   => pharmacode,
              :ppub         => line[6].gsub(/\s|Fr\./,''),
              :article_name_de => line[7].gsub(/,([^\s])/, ", \\1"),
              :article_name_fr => line[8].gsub(/,([^\s])/, ", \\1"),
            }
            # puts "#{Time.now}: Short/long do not match in line #{count}: #{line}" unless line[3].eql?(line[8]) && line[2].eql?(line[7])

            @migel_codes_with_products << migel_code
            if with_matching_pharmacode.size == 1
              update_product_from_csv(migelid, record)
              puts "#{Time.now}: updating via_pharmacode: " + estimate_time(@start_time, total, count, ' ') + "migel_code: #{migel_code}" if estimate
            elsif with_matching_ean.size >= 1
              update_product_from_csv(migelid, record)
              puts "#{Time.now}: updating via_ean: " + estimate_time(@start_time, total, count, ' ') + "migel_code: #{migel_code} ean13 #{ean13}" if estimate
            elsif with_matching_ean.size == 0 && with_matching_pharmacode.size == 0
              update_product_from_csv(migelid, record)
              puts "#{Time.now}: Added as no matching ean/pharmacode found: " + estimate_time(@start_time, total, count, ' ') + "migel_code: #{migel_code} #{ean13}/#{pharmacode}" if estimate
            else
              puts "#{Time.now}: Skipping : " + estimate_time(@start_time, total, count, ' ') + "migel_code: #{migel_code} #{ean13}/#{pharmacode}" if estimate
            end
          else
            @migel_codes_without_products << migel_code
            puts "#{Time.now}: ignoring as no code found: " + estimate_time(@start_time, total, count, ' ') + "migel_code: #{migel_code} ean13 #{ean13}" if estimate
          end
        end
        clear_inactive_bauerfeind_products
        @nr_products_after = get_nr_active_bauerfeind_products
        puts "#{Time.now}: finished: count #{count}: @nr_records #{@nr_records} " +
            "@migel_codes_without_products #{@migel_codes_without_products.size} @migel_codes_with_products #{@migel_codes_with_products.uniq}"
        true
      end
      private
      def get_nr_active_bauerfeind_products
        Migel::Model::Product.all.find_all{|x| x.status == 'A' && /bauerfeind/i.match(x.companyname.to_s)}.size
      end
      def clear_inactive_bauerfeind_products
        items = 0
        Migel::Model::Migelid.all.each do |migel_id|
            migel_code = migel_id.migel_code
            nr_invalids = migel_id.products.find_all{|x| x.status == 'I' && /Bauerfeind/i.match(x.companyname.to_s) }.size
            if nr_invalids > 0
              items += nr_invalids
              puts "#{Time.now}: Total #{items}: Deleting  #{nr_invalids} items for #{migel_code} by Bauerfeind"
              migel_id.products.delete_if{|x| x.status == 'I' && /Bauerfeind/i.match(x.companyname.to_s)  }
              migel_id.save
            end
        end
        puts "#{Time.now}: Deleted #{items} inactive Bauerfeind items"
      end
     def set_bauerfeind_products_inactive
       items = 0
       Migel::Model::Product.all.find_all{|x| x.status == 'A' && /bauerfeind/i.match(x.companyname.to_s)}.each{|x| x.status = 'I'; x.save; items += 1 }
       puts "#{Time.now}: Set #{items} Bauerfeind items to inactive"
      end
      def update_product_from_csv(migelid, record)
        found = true
        key_value = record[:pharmacode].to_i != 0 ? record[:pharmacode] : record[:ean_code]
        product = migelid.products.find do |i| i.pharmacode.eql?(key_value) end || begin
          found = false
          orig_size = migelid.products.size
          origs_size2 = Migel::Util::Server.new.all_products.size
          i = Migel::Model::Product.new(key_value)
          sleep 0.01
          migelid.products.push i
          sleep 0.01
          migelid.save
          i
        end
        product.migelid = migelid
        product.pharmacode = key_value unless product.pharmacode.eql?(key_value)
        product.ean_code = record[:ean_code]
        product.send(:companyname).send('de=', Companyname_DE)
        product.send(:companyname).send('fr=', Companyname_FR)
        product.status = Status_csv_items
        product.ppub = record[:ppub]
        product.send(:article_name).send('de=', record[:article_name_de])
        product.send(:article_name).send('fr=', record[:article_name_fr])
        product.save
      end
    end

  end
end
