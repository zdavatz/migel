#!/usr/bin/env ruby
# encoding: utf-8
# Migel::Importer -- migel -- 13.02.2012 -- yasaka@ywesee.com
# Migel::Importer -- migel -- 06.01.2012 -- mhatakeyama@ywesee.com

require 'csv'
require 'fileutils'
require 'zlib'
require 'migel/util/mail'
require 'migel/plugin/swissindex'
require 'spreadsheet'
require 'open-uri'
require 'migel/util/server'

module Migel
  LANGUAGE_NAMES = { 'de' => 'MiGeL',
      'fr' => 'LiMA',
      'it' => 'EMAp',
                  }

  module Util
def estimate_time(start_time, total, count, lb="\n")
  estimate = (Time.now - start_time) * total / count
  log = '%3d' % count.to_s + " / " + total.to_s + "\t"
  em   = estimate/60
  eh   = em/60
  rest = estimate - (Time.now - start_time)
  rm   = rest/60
  rh   = rm/60
  log << "Estimate total: "
  if eh > 1.0
    log << "%.2f" % eh + " [h]"
  else
    log << "%.2f" % em + " [m]"
  end
  log << " It will be done in: "
  if rh > 1.0
    log << "%.2f" % rh + " [h]"
  else
    log << "%.2f" % rm + " [m]"
  end
  log << lb
  log
end
class Importer
	attr_reader :data_dir
	attr_reader :xls_file
	OriginalXLS = 'https://github.com/zdavatz/oddb2xml_files/raw/master/MiGeL.xls'
  SALE_TYPES = {
    '1' => :purchase,
    '2' => :rent,
    '3' => :both,
  }
  def initialize
    @data_dir = File.expand_path('../../../data/csv', File.dirname(__FILE__))
    $stdout.sync = true
    FileUtils.mkdir_p @data_dir
    @xls_file = File.join(@data_dir, File.basename(OriginalXLS))
    @start_time = Time.now
  end
  def date_object(date)
    date = date.to_s.split(".")
    if(date.size == 3)
      Date.new(date.at(2).to_i, date.at(1).to_i, date.at(0).to_i)
    end
  end

  def update_all
    puts "#{Time.now}: update_all using #{@xls_file}"
    base = File.basename(@xls_file, '.xls')
    xls = File.open(@xls_file, 'wb+')
    open(OriginalXLS) {|f| xls.write(f.read ) }
    xls.close
    actContent = File.read(@xls_file)

    latest = File.join(@data_dir, base + '-latest.xls')
    target = File.join(@data_dir, "#{base}-#{Time.now.strftime('%Y.%m.%d')}.xls")
    if !File.exist?(target) || File.read(target) != actContent
      FileUtils.cp(@xls_file, target, :verbose => true, :preserve => true)
    end
    if File.exist?(latest) && File.read(latest) == actContent
      return
    end
    puts "#{Time.now}: update_all #{@xls_file} taken from #{OriginalXLS}"
    book = Spreadsheet.open @xls_file
    LANGUAGE_NAMES.each{
        |language, name|
      sheet = book.worksheet(name)
      csv_name = File.join(@data_dir, "migel_#{language}.csv")
      idx = 0
      CSV.open(csv_name, 'w') do |writer|
        sheet.rows.each do |row|
          # fix conversion to date
          row[20] = row[20].strftime('%d.%m.%Y') if row[20].to_s.to_i > 0
          writer << row
          idx += 1
          puts "#{Time.now}: update_all #{language} #{@xls_file} at row #{idx} #{row[13]}" if idx % 500 == 0
        end
      end
      update(csv_name, language) #   unless defined?(RSpec)
    }
    FileUtils.mv(@xls_file, latest, :verbose => true)
  end
  # for import groups, subgroups, migelids
  def update(path, language)
    puts "#{Time.now}: update #{path} #{language}"
    # update Group, Subgroup, Migelid data from a csv file
    CSV.readlines(path)[1..-1].each do |row|
      id = row.at(13).to_s.split('.')
      if(id.empty?)
        id = row.at(4).to_s.split('.')
      else
        id[-1].replace(id[-1][0,1])
      end
      unless id.empty?
        group = update_group(id, row, language)
        subgroup = update_subgroup(id, group, row, language)
        migel_code_list.delete(group.migel_code)
        migel_code_list.delete(subgroup.migel_code)
        if(id.size > 2)
          migelid = update_migelid(id, subgroup, row, language)
          migel_code_list.delete(migelid.migel_code)
          if migelid.date && migelid.date.year < 1900
            $stderr.puts "#{__LINE__}: save migelid #{migelid.migel_code} #{migelid.date}"
            # require 'pry'; binding.pry
          end
        end
      end
    end

    # delete not updated list
    migel_code_list.each do |migel_code|
      case migel_code.length
      when 2
        Migel::Model::Group.find_by_migel_code(migel_code).delete if Migel::Model::Group.find_by_migel_code(migel_code)
      when 5
        Migel::Model::Subgroup.find_by_migel_code(migel_code).delete if Migel::Model::Subgroup.find_by_migel_code(migel_code)
      else
        Migel::Model::Migelid.find_by_migel_code(migel_code).delete if Migel::Model::Migelid.find_by_migel_code(migel_code)
      end
    end
  end
  def update_group(id, row, language)
    groupcd = id.at(0)
    puts "#{Time.now}: update_group #{id} groupcd #{groupcd} #{language}" if id.size < 5
    group = Migel::Model::Group.find_by_code(groupcd) || Migel::Model::Group.new(groupcd)
    group.name.send(language.to_s + '=', row.at(2).to_s)
    text = row.at(3).to_s
    text.tr!("\v", " ")
    text.strip!
    group.update_limitation_text(text, language) unless text.empty?
    group.save
    group
  end
  def update_subgroup(id, group, row, language)
    subgroupcd = id.at(1)
    subgroup = group.subgroups.find{|sg| sg.code == subgroupcd} || begin
      sg = Migel::Model::Subgroup.new(subgroupcd)
      group.subgroups.push sg
      group.save
      sg
    end
    subgroup.group = group
    subgroup.name.send(language.to_s + '=', row.at(6).to_s)
    if text = row.at(7).to_s and !text.empty?
      subgroup.update_limitation_text(text, language) 
    end
    subgroup.save
    subgroup
  end
  def update_migelid(id,  subgroup, row, language)
    # take data from csv
    migelidcd = id[2,3].join(".")
    name = row.at(12).to_s
    migelid_text = row.at(15).gsub(/[ \t]+/u, " ")
    migelid_text.tr!("\v", "\n")
    limitation_text = if(idx = migelid_text.index(/Limitation|Limitazione/u))
                        migelid_text.slice!(idx..-1).strip
                      else
                        ''
                      end
    if(name.to_s.strip.empty?)
      name = migelid_text.slice!(/^[^\n]+/u)
    end
    migelid_text.strip!
    type = SALE_TYPES[id.at(4)]
    price = ((row.at(18).to_s[/\d[\d.]*/u].to_f) * 100).round
    date = row.at(20) ? Date.parse(row.at(20)) : nil
    limitation = (row.at(14) == 'L')
    qty = row.at(16).to_i
    unit = row.at(17).to_s
    # save instance
    migelid = subgroup.migelids.find{|mi| mi.code == migelidcd} || begin
      mi = Migel::Model::Migelid.new(migelidcd)
      subgroup.migelids.push mi
      subgroup.save
      mi
    end
    migelid.subgroup = subgroup
    migelid.save
    migelid.limitation_text(true)
    multilingual_data = {
      :name            => name,
      :migelid_text    => migelid_text,
      :limitation_text => limitation_text,
      :unit => unit,
    }
    migelid.update_multilingual(multilingual_data, language)
    migelid.type  = type
    migelid.price = price
    migelid.date  = date
    if migelid.date && migelid.date.year < 1900
      $stderr.puts "#{__LINE__}: Problem with #{migelid.migel_code} #{migelid.date}"
      # require 'pry'; binding.pry
    end
    migelid.limitation = limitation
    migelid.qty = qty if qty > 0

    if(id[3] != "00")
      1.upto(3) { |num|
        micd =  [id[2], '00', num].join('.')
        if mi = subgroup.migelids.find{|m| m.code == micd}
          migelid.add_migelid(mi)
        end
      }
    end

    migelid.save
    migelid
  end

  def save_all_products_all_languages(options = {:report => false, :estimate => false})
    LANGUAGE_NAMES.each do
      |language, name|
        file_name = File.join(@data_dir, "migel_products_#{language}.csv")
        reported_save_all_products(file_name, language, options[:estimate])
        unless defined?(RSpec)
          raise "Trying to save emtpy (or too small) #{file_name}" unless File.exist?(file_name) && File.size(file_name) > 1024
        end
    end
  end

  # for import products
  def reported_save_all_products(file_name = 'migel_products_de.csv', lang = 'de', estimate = false)
    @csv_file = File.join(@data_dir, File.basename(file_name))
    lines = [
      sprintf("%s: %s %s#reported_save_all_products(#{lang})", Time.now.strftime('%c'), Migel.config.server_name, self.class)
    ]
    save_all_products(@csv_file, lang, estimate)
    compressed_file = compress(@csv_file)
    historicize(compressed_file)
    lines.concat report(lang)
  rescue Exception => err
    lines.push(err.class.to_s, err.message, *err.backtrace)
    lines.concat report
  ensure
    subject = lines[0]
    Migel::Util::Mail.notify_admins_attached(subject, lines, compressed_file)
  end
  def historicize(filepath)
    archive_path = File.expand_path('../../../data', File.dirname(__FILE__))
    save_dir = File.join archive_path, 'csv'
    FileUtils.mkdir_p save_dir
    archive = Date.today.strftime(filepath.gsub(/\.csv\.gz/,"-%Y.%m.%d.csv.gz"))
    puts "#{Time.now}: historicize #{filepath} -> #{archive}. Size is #{File.size(filepath)}"
    FileUtils.cp(filepath, archive)
  end
  def compress(file)
    puts "#{Time.now}: compress #{file}"
    compressed_filename = file + '.gz'
    Zlib::GzipWriter.open(compressed_filename, Zlib::BEST_COMPRESSION) do |gz|
      gz.mtime = File.mtime(file)
      gz.orig_name = file
      gz.puts File.open(file, 'rb'){|f| f.read }
    end
    compressed_filename
  end
  def report(lang = 'de')
    lang = lang.downcase
    end_time = Time.now - @start_time
    @update_time = (end_time / 60.0).to_i
    res = [
      "Total time to update: #{"%.2f" % @update_time} [m]",
      "Saved file: #{@csv_file}",
      sprintf("Total %5i Migelids (%5i Migelids have products / %5i Migelids have no products)",
              migel_code_list               ? migel_code_list.length : 0,
              @migel_codes_with_products    ? @migel_codes_with_products.length : 0,
              @migel_codes_without_products ? @migel_codes_without_products.length : 0),
      "Saved #{@saved_products} Products",
    ]
    res += [
      '',
      "Migelids with products (#{@migel_codes_with_products ? @migel_codes_with_products.length : 0})"
    ]
    res += @migel_codes_with_products.sort.map{|migel_code|
      "http://ch.oddb.org/#{lang}/gcc/migel_search/migel_product/#{migel_code}"
    } if @migel_codes_with_products
    res += [
      '',
      "Migelids without products (#{@migel_codes_without_products ? @migel_codes_without_products.length : 0})"
    ]
    res[-1] += @migel_codes_without_products.sort.map{|migel_code|
      "http://ch.oddb.org/#{lang}/gcc/migel_search/migel_product/#{migel_code}"}.to_s if @migel_codes_without_products and @migel_codes_without_products.size > 0
    res
  end
  def code_list(index_table_name, output_filename = nil)
    list = ODBA.cache.index_keys(index_table_name)
    if output_filename
      File.open(output_filename, 'w') do |out|
        out.print list.join("\n"), "\n"
      end
    end
    list
  end
  def migel_code_list(output_filename = nil)
    @migel_code_list ||= begin
      index_table_name = 'migel_model_migelid_migel_code'
      code_list(index_table_name, output_filename)
    end
    @migel_code_list ||= []
  end
  def pharmacode_list(output_filename = nil)
    @pharmacode_list ||= begin
      index_table_name = 'migel_model_product_pharmacode'
      code_list(index_table_name, output_filename)
    end
    @pharmacode_list ||= []
  end
  def unimported_migel_code_list(output_filename = nil)
    migel_codes = migel_code_list.select do |migel_code|
      migelid = Migel::Model::Migelid.find_by_migel_code(migel_code) and migelid.products.empty?
    end
    if output_filename
      File.open(output_filename, 'w') do |out|
        out.print migel_codes.join("\n"), "\n"
      end
    end
    migel_codes
  end
  def missing_article_name_migel_code_list(lang = 'de', output_filename = nil)
    migel_codes = migel_code_list.select do |migel_code|
      migelid = Migel::Model::Migelid.find_by_migel_code(migel_code) and !migelid.products.empty? and migelid.products.first.article_name.send(lang).to_s.empty?
    end
    if output_filename 
      File.open(output_filename, 'w') do |out|
        out.print migel_codes.join("\n"), "\n"
      end
    end
    migel_codes
  end
  def reimport_missing_data(lang = 'de', estimate = false)
    migel_codes = missing_article_name_migel_code_list

    total = migel_codes.length
    start_time = Time.now
    migel_codes.each_with_index do |migel_code, count|
      update_products_by_migel_code(migel_code, lang)
      puts estimate_time(start_time, total, count+1) if estimate
    end
    migel_codes.length.to_s + ' migelids is updated.'
  end
  def save_all_products(file_name = 'migel_products_de.csv', lang = 'de', estimate = false)
    plugin = Migel::SwissindexMigelPlugin.new(migel_code_list)
    @saved_products, @migel_codes_with_products, @migel_codes_without_products =
      plugin.save_all_products(file_name, lang, estimate)
  end
  def import_all_products_from_csv(file_name = 'migel_products_de.csv', lang = 'de', estimate = false)
    lang.upcase!
    start_time = Time.new
    total = File.readlines(file_name).to_a.length
    count = 0
    # update cache
    CSV.foreach(file_name) do |line|
      count += 1
      line[0] = line[0].rjust(9, '0') if line[0] =~ /^\d{8}$/
      migel_code = if line[0] =~ /^\d{9}$/
                     line[0].split(/(\d\d)/).select{|x| !x.empty?}.join('.')
                   elsif line[0] =~ /^(\d\d)\.(\d\d)\.(\d\d)\.(\d\d)\.(\d)$/
                     line[0]
                   else
                     '' # skip
                   end
      if migelid = Migel::Model::Migelid.find_by_migel_code(migel_code)
        record = {
          :pharmacode   => line[1],
          :ean_code     => line[2],
          :article_name => line[3],
          :companyname  => line[4],
          :companyean   => line[5],
          :ppha         => line[6],
          :ppub         => line[7],
          :factor       => line[8],
          :pzr          => line[9],
          :size         => line[10],
          :status       => line[11],
          :datetime     => line[12],
          :stdate       => line[13],
          :language     => line[14],
        }
        update_product(migelid, record, lang)
        pharmacode_list.delete(line[1])
        puts "updating: " + estimate_time(start_time, total, count, ' ') + "migel_code: #{migel_code}" if estimate
      else
        puts "ignoring: " + estimate_time(start_time, total, count, ' ') + "migel_code: #{migel_code}" if estimate
      end
    end

    # update database
    count = 0
    start_time = Time.new
    total = migel_code_list.length
    codes = migel_code_list.dup
    codes.each do |migel_code|
      count += 1
      if migelid = Migel::Model::Migelid.find_by_migel_code(migel_code)
        migelid = migelid.dup
        migelid.products.each do |product|
          product.save
        end
        $stderr.puts "#{__LINE__}: saving migelid #{migelid.migel_code} #{migelid.date}"
        migelid.save
        puts "saving: " + estimate_time(start_time, total, count, ' ') + "migel_code: #{migel_code}" if estimate
      else
        puts "ignoring: " + estimate_time(start_time, total, count, ' ') + "migel_code: #{migel_code}" if estimate
      end
    end

    # delete process
    pharmacode_list.each do |pharmacode|
      Migel::Model::Product.find_by_pharmacode(pharmacode).delete
    end
  end
  def update_products_by_migel_code(migel_code, lang = 'de')
    lang.upcase!
    if migelid = Migel::Model::Migelid.find_by_migel_code(migel_code)
      migel_code = migelid.migel_code.split('.').to_s
      if table = ODDB::Swissindex.search_migel_table(migel_code, lang)
        table.each do |record|
          if record[:pharmacode] and record[:article_name]
            update_product(migelid, record, lang)
          end
        end
      end
      migelid.products.each do |product|
        product.save
      end
      $stderr.puts "#{__LINE__}: saving migelid #{migelid.migel_code} #{migelid.date}"
      migelid.save
    end
  end
  private
  def update_product(migelid, record, lang = 'de')
    lang.downcase!
    product = migelid.products.find{|i| i.pharmacode == record[:pharmacode]} || begin
      i = Migel::Model::Product.new(record[:pharmacode])
      sleep 0.01
      migelid.products.push i
      sleep 0.01
#      migelid.save
      i
    end
    product.migelid = migelid
    #product.save

    product.ean_code     = record[:ean_code]
    #product.article_name = record[:article_name]
    product.send(:article_name).send(lang.to_s + "=", record[:article_name])
    #product.companyname  = record[:companyname]
    product.send(:companyname).send(lang.to_s + "=", record[:companyname])
    product.companyean   = record[:companyean]
    product.ppha         = record[:ppha]
    product.ppub         = record[:ppub]
    product.factor       = record[:factor]
    product.pzr          = record[:pzr]
    #product.size         = record[:size]
    product.send(:size).send(lang.to_s + "=", record[:size])
    product.status       = record[:status]
    product.datetime     = record[:datetime]
    product.stdate       = record[:stdate]
    product.language     = record[:language]

#    product.save
    product
  end
end

  end
end

include Migel::Util
