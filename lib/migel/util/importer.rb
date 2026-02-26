#!/usr/bin/env ruby
# encoding: utf-8
# Migel::Importer -- migel -- 13.02.2012 -- yasaka@ywesee.com
# Migel::Importer -- migel -- 06.01.2012 -- mhatakeyama@ywesee.com

require 'csv'
require 'fileutils'
require 'set'
require 'zlib'
require 'migel/util/mail'
require 'migel/plugin/swissindex'
require 'spreadsheet'
require 'rubyXL'
require 'rubyXL/convenience_methods'
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
	BAG_XLSX_URL = 'https://www.bag.admin.ch/dam/de/sd-web/77j5rwUTzbkq/Mittel-%20und%20Gegenst%C3%A4ndeliste%20per%2001.01.2026%20in%20Excel-Format.xlsx'
	GS1_CSV_URL = 'https://id.gs1.ch/01/07612345000961'
  SALE_TYPES = {
    '1' => :purchase,
    '2' => :rent,
    '3' => :both,
  }
  # Old MiGeL.xls column indices (kept for backward compatibility)
  Produktegruppe_Nr = 0
  Limitation_Produktegruppe = 1
  Produktegruppe = 2
  Beschreibung_Produktegruppe = 3
  Kategorie_Nr = 4 #  Kategorie Nr
  Kategorie  = 6
  Beschreibung_Kategorie  = 7
  Unterkategorie = 12
  Positions_Nummer = 15
  Limitation = 16
  Bezeichnung = 17
  Menge = 18
  Einheit = 19
  Max_Price = 20 #      Höchstvergütungsbetrag =
  Revision_Valid_since = 22 # Revision Gültig ab

  # BAG XLSX column indices
  BAG_COL_PRODUKTEGRUPPE = 0
  BAG_COL_KATEGORIE = 1
  BAG_COL_POSITIONS_NR = 7
  BAG_COL_LIMITATION_FLAG = 8
  BAG_COL_BEZEICHNUNG = 9
  BAG_COL_LIMITATION_TEXT = 10
  BAG_COL_MENGE_EINHEIT = 11
  BAG_COL_HVB_SELBST = 12
  BAG_COL_HVB_PFLEGE = 13
  BAG_COL_GUELTIG_AB = 14

  BAG_LANGUAGE_SHEETS = {
    'de' => 'MiGeL D',
    'fr' => 'MiGeL F',
    'it' => 'MiGeL I',
  }

  def initialize
    @data_dir = File.expand_path('../../../data/csv', File.dirname(__FILE__))
    @xlsx_dir = File.expand_path('../../../data/xlsx', File.dirname(__FILE__))
    $stdout.sync = true
    FileUtils.mkdir_p @data_dir
    FileUtils.mkdir_p @xlsx_dir
    @xls_file = File.join(@data_dir, File.basename(OriginalXLS))
    @start_time = Time.now
  end
  def date_object(date)
    date = date.to_s.split(".")
    if(date.size == 3)
      Date.new(date.at(2).to_i, date.at(1).to_i, date.at(0).to_i)
    end
  end

  def check_headers(row)
    expected = {
      Produktegruppe_Nr => 'Produktegruppe Nr',
      Produktegruppe => 'Produktegruppe',
      Beschreibung_Produktegruppe => 'Beschreibung Produktegruppe',
      Kategorie_Nr => 'Kategorie Nr',
      Kategorie  => 'Kategorie',
      Beschreibung_Kategorie  => 'Beschreibung Kategorie',
      Unterkategorie => 'Unterkategorie',
      Positions_Nummer => 'Positions Nummer',
      Limitation => 'Limitation',
      Bezeichnung => 'Bezeichnung',
      Menge => 'Menge',
      Einheit => 'Einheit',
      Max_Price => 'Höchstvergütungsbetrag' ,
      Revision_Valid_since => 'Revision Gültig ab',
    }
    expected.each do |key, value|
      next if row[key].eql?(value)
      raise "Unexpected name #{row[key]} for key #{key.to_s} #{value}"
    end
  end

  def update_all
    xlsx_file = File.join(@xlsx_dir, 'MiGeL_BAG.xlsx')
    puts "#{Time.now}: update_all downloading BAG XLSX from #{BAG_XLSX_URL}"
    File.open(xlsx_file, 'wb+') do |f|
      URI.open(BAG_XLSX_URL) { |remote| f.write(remote.read) }
    end

    latest = File.join(@xlsx_dir, 'MiGeL_BAG-latest.xlsx')
    target = File.join(@xlsx_dir, "MiGeL_BAG-#{Time.now.strftime('%Y.%m.%d')}.xlsx")
    act_content = File.read(xlsx_file)
    if !File.exist?(target) || File.read(target) != act_content
      FileUtils.cp(xlsx_file, target, :verbose => true, :preserve => true)
    end
    if File.exist?(latest) && File.read(latest) == act_content
      puts "#{Time.now}: update_all BAG XLSX unchanged, skipping"
      return
    end

    puts "#{Time.now}: update_all parsing BAG XLSX #{xlsx_file}"
    book = RubyXL::Parser.parse(xlsx_file)

    BAG_LANGUAGE_SHEETS.each do |language, sheet_name|
      sheet = book[sheet_name]
      unless sheet
        puts "#{Time.now}: WARNING: sheet '#{sheet_name}' not found, skipping #{language}"
        next
      end
      puts "#{Time.now}: update_all processing sheet '#{sheet_name}' (#{language}), #{sheet.count} rows"
      update_from_bag_sheet(sheet, language)
    end

    FileUtils.mv(xlsx_file, latest, :verbose => true)
    puts "#{Time.now}: update_all done"
  end

  def update_from_bag_sheet(sheet, language)
    current_group = nil
    current_subgroup = nil
    row_count = 0

    (1..sheet.count - 1).each do |r|
      next unless sheet[r]
      cells = sheet[r].cells
      produktegruppe = cells[BAG_COL_PRODUKTEGRUPPE]&.value.to_s.strip
      kategorie = cells[BAG_COL_KATEGORIE]&.value.to_s.strip
      pos_nr = cells[BAG_COL_POSITIONS_NR]&.value.to_s.strip
      bezeichnung = cells[BAG_COL_BEZEICHNUNG]&.value.to_s.gsub(/[\v\r]/, "\n").strip
      limitation_text = cells[BAG_COL_LIMITATION_TEXT]&.value.to_s.gsub(/[\v\r]/, "\n").strip
      limitation_flag = cells[BAG_COL_LIMITATION_FLAG]&.value.to_s.strip
      menge_einheit = cells[BAG_COL_MENGE_EINHEIT]&.value.to_s.strip
      hvb_selbst = cells[BAG_COL_HVB_SELBST]&.value
      hvb_pflege = cells[BAG_COL_HVB_PFLEGE]&.value
      gueltig_ab = cells[BAG_COL_GUELTIG_AB]&.value

      if pos_nr.length > 0
        # Position row — create/update migelid
        current_group, current_subgroup = update_bag_migelid(
          pos_nr, bezeichnung, limitation_text, limitation_flag,
          menge_einheit, hvb_selbst, hvb_pflege, gueltig_ab,
          current_group, current_subgroup, language
        )
        row_count += 1
      elsif kategorie.length > 0 && kategorie != " "
        # Subgroup header row
        current_subgroup = update_bag_subgroup(kategorie, bezeichnung, limitation_text, current_group, language)
      elsif produktegruppe.length > 0 && produktegruppe != " "
        # Group header row
        current_group = update_bag_group(produktegruppe, bezeichnung, limitation_text, language)
        current_subgroup = nil
      end

      puts "#{Time.now}: update_all #{language} processed #{row_count} positions" if row_count > 0 && row_count % 200 == 0
    end
    puts "#{Time.now}: update_all #{language} done, #{row_count} positions processed"
  end

  def update_bag_group(code, bezeichnung, limitation_text_str, language)
    # code is e.g. "01"
    groupcd = code.strip
    group = Migel::Model::Group.find_by_code(groupcd) || Migel::Model::Group.new(groupcd)
    group.name.send(language.to_s + '=', bezeichnung)
    if limitation_text_str && !limitation_text_str.empty?
      text = limitation_text_str.tr("\v", " ").strip
      group.update_limitation_text(text, language) unless text.empty?
    end
    group.save
    migel_code_list.delete(group.migel_code)
    group
  rescue => error
    puts "#{Time.now}: ERROR update_bag_group #{code}: #{error}"
    nil
  end

  def update_bag_subgroup(code, bezeichnung, limitation_text_str, group, language)
    # code is e.g. "01.01" — extract the subgroup part after the dot
    parts = code.split('.')
    subgroupcd = parts.last
    unless group
      # Try to find group from the code prefix
      groupcd = parts.first
      group = Migel::Model::Group.find_by_code(groupcd)
    end
    return nil unless group

    subgroup = group.subgroups.find { |sg| sg.code == subgroupcd } || begin
      sg = Migel::Model::Subgroup.new(subgroupcd)
      group.subgroups.push sg
      group.save
      sg
    end
    subgroup.group = group
    subgroup.name.send(language.to_s + '=', bezeichnung)
    if limitation_text_str && !limitation_text_str.empty?
      subgroup.update_limitation_text(limitation_text_str, language)
    end
    subgroup.save
    migel_code_list.delete(subgroup.migel_code)
    subgroup
  rescue => error
    puts "#{Time.now}: ERROR update_bag_subgroup #{code}: #{error}"
    nil
  end

  def update_bag_migelid(pos_nr, bezeichnung, limitation_text_str, limitation_flag,
                          menge_einheit, hvb_selbst, hvb_pflege, gueltig_ab,
                          current_group, current_subgroup, language)
    # pos_nr is e.g. "01.01.01.00.1"
    parts = pos_nr.split('.')
    groupcd = parts[0]
    subgroupcd = parts[1]
    migelidcd = parts[2..4].join('.')  # e.g. "01.00.1"

    # Ensure we have the right group/subgroup
    if current_group.nil? || current_group.code != groupcd
      current_group = Migel::Model::Group.find_by_code(groupcd)
    end
    return [current_group, current_subgroup] unless current_group

    if current_subgroup.nil? || current_subgroup.code != subgroupcd
      current_subgroup = current_group.subgroups.find { |sg| sg.code == subgroupcd }
    end
    return [current_group, current_subgroup] unless current_subgroup

    migelid = current_subgroup.migelids.find { |mi| mi.respond_to?(:code) && mi.code == migelidcd } || begin
      mi = Migel::Model::Migelid.new(migelidcd)
      current_subgroup.migelids.push mi
      current_subgroup.save
      mi
    end
    migelid.subgroup = current_subgroup

    # Parse name and migelid_text from Bezeichnung
    text = bezeichnung.gsub(/[ \t]+/u, " ")
    name = text.slice!(/^[^\n]+/u).to_s.strip
    migelid_text = text.strip

    # Price: use HVB Selbstanwendung (col 12), fall back to HVB Pflege (col 13)
    price_val = hvb_selbst || hvb_pflege
    price = if price_val
              ((price_val.to_s[/\d[\d.]*/u].to_f) * 100).round
            else
              0
            end

    # Parse qty and unit from combined "Menge / Einheit" field
    qty = 0
    unit = ''
    if menge_einheit && !menge_einheit.empty?
      if menge_einheit =~ /^(\d+)\s*(.*)/
        qty = $1.to_i
        unit = $2.strip
      else
        unit = menge_einheit
      end
    end

    # Parse date
    date = nil
    if gueltig_ab
      begin
        if gueltig_ab.is_a?(DateTime) || gueltig_ab.is_a?(Date)
          date = gueltig_ab.to_date
        else
          date = Date.parse(gueltig_ab.to_s)
        end
      rescue => error
        puts "#{Time.now}: WARNING: could not parse date '#{gueltig_ab}': #{error}"
      end
    end

    limitation = (limitation_flag == 'L')

    migelid.limitation_text(true)
    multilingual_data = {
      :name            => name,
      :migelid_text    => migelid_text,
      :limitation_text => limitation_text_str || '',
      :unit            => unit,
    }
    migelid.update_multilingual(multilingual_data, language)
    migelid.price = price
    migelid.date  = date
    migelid.limitation = limitation
    migelid.qty = qty if qty > 0
    migelid.save

    migel_code_list.delete(migelid.migel_code)
    [current_group, current_subgroup]
  rescue => error
    puts "#{Time.now}: ERROR update_bag_migelid #{pos_nr}: #{error}"
    [current_group, current_subgroup]
  end
  def update_products_from_gs1
    gs1_file = File.join(@data_dir, 'gs1_migel.csv')
    puts "#{Time.now}: update_products_from_gs1 downloading #{GS1_CSV_URL}"
    File.open(gs1_file, 'wb+') do |f|
      URI.open(GS1_CSV_URL) { |remote| f.write(remote.read) }
    end
    puts "#{Time.now}: update_products_from_gs1 parsing #{gs1_file}"

    created_count = 0
    updated_count = 0
    row_count = 0
    CSV.foreach(gs1_file, headers: true, encoding: 'bom|utf-8') do |row|
      gtin = row['Gtin']
      next unless gtin && !gtin.empty?
      row_count += 1

      # Find existing product by EAN or create new one using GTIN as pharmacode
      product = Migel::Model::Product.find_by_ean_code(gtin)
      if product.is_a?(Array)
        product = product.first
      end
      if product
        updated_count += 1
      else
        product = Migel::Model::Product.new(gtin)
        product.ean_code = gtin
        created_count += 1
      end

      product.article_name.de = row['TradeItemDescription_DE'] if row['TradeItemDescription_DE']
      product.article_name.fr = row['TradeItemDescription_FR'] if row['TradeItemDescription_FR']
      product.article_name.it = row['TradeItemDescription_IT'] if row['TradeItemDescription_IT']

      company = row['InformationProviderPartyName']
      if company && !company.empty?
        product.companyname.de = company
        product.companyname.fr = company
        product.companyname.it = company
      end

      product.companyean = row['InformationProviderGln'] if row['InformationProviderGln']

      net_value = row['NetContent_Value']
      net_unit = row['NetContent_MeasurementUnitCode']
      if net_value && !net_value.empty?
        size_str = [net_value, net_unit].compact.reject(&:empty?).join(' ')
        product.size.de = size_str
        product.size.fr = size_str
        product.size.it = size_str
      end

      product.datetime = row['LastChangeDateTime'] if row['LastChangeDateTime']

      product.save
      puts "#{Time.now}: update_products_from_gs1 #{row_count} rows processed (#{created_count} created, #{updated_count} updated)" if row_count % 10000 == 0
    end
    puts "#{Time.now}: update_products_from_gs1 done. #{row_count} rows: #{created_count} created, #{updated_count} updated"

    # Text-match products to migelids
    match_products_to_migelids
  end

  # Stop words: articles, prepositions, conjunctions, and generic medical/product terms
  # that match too broadly. Ported from fb2sqlite/src/migel.rs.
  STOPWORDS = %w[
    der die das den dem des ein eine eines einem einen einer
    fuer mit von und oder bei auf nach ueber unter aus bis
    pro als inkl exkl max min per zur zum ins vom ohne
    auch sich noch wenn muss darf resp bzw
    kauf miete tag jahr monate stueck set alle nur
    wird ist kann sind werden wurde hat haben
    steril unsteril sterile non
    diverse divers diversi
    gross klein lang kurz
    position definierte einstellbare
    les des pour avec par une dans sur qui que
    achat location piece sans
    acquisto noleggio pezzo senza
    the for and with per
    material produkt products product medical device
    system systeme systems geraet geraete appareil
    compression compressione kompression
    verlaengerung extension estensione prolongation
    silikon silicone
    ecarteur divaricatore retraktor
  ].to_set.freeze

  # Normalize German umlauts and accented characters so ALL-CAPS text
  # (e.g. ABSAUGGERAETE) matches proper text (e.g. Absauggeräte).
  UMLAUT_MAP = {
    'ä' => 'ae', 'ö' => 'oe', 'ü' => 'ue', 'ß' => 'ss',
    'é' => 'e', 'è' => 'e', 'ê' => 'e', 'à' => 'a', 'â' => 'a',
    'ù' => 'u', 'û' => 'u', 'ô' => 'o', 'î' => 'i', 'ç' => 'c',
  }.freeze

  def normalize_german(text)
    result = text.downcase
    UMLAUT_MAP.each { |from, to| result = result.gsub(from, to) }
    result
  end

  # Extract keywords from text (min_len chars, after normalization and stop word removal)
  def extract_keywords(text, min_len = 3)
    return [] unless text
    normalize_german(text)
      .split(/[^a-z0-9]+/)
      .select { |w| w.length >= min_len }
      .reject { |w| STOPWORDS.include?(w) }
      .uniq
  end

  # Extract only long (>= 8 char) keywords from additional lines (not first line).
  # These are specific enough to use as bonus scoring keywords.
  def extract_secondary_keywords(text)
    return [] unless text
    lines = text.split("\n")
    return [] if lines.size <= 1
    rest = lines[1..].join(' ')
    extract_keywords(rest, 8)
  end

  # Split text into words for word-level matching
  def split_words(text)
    text.split(/[^a-z0-9]+/).reject(&:empty?)
  end

  # Check if keyword matches at word level.
  # suffix: if true, also matches as suffix of compound word (German)
  # fuzzy: if true, also tries keyword truncated by 1 char (German plural/case)
  def word_match?(text_words, keyword, suffix: false, fuzzy: false)
    text_words.each do |word|
      return true if word == keyword
      if suffix && word.length > keyword.length + 2 && word.end_with?(keyword)
        return true
      end
    end
    if fuzzy && keyword.length >= 7
      trunc = keyword[0..-2]
      text_words.each do |word|
        return true if word == trunc
        if suffix && word.length > trunc.length + 2 && word.end_with?(trunc)
          return true
        end
      end
    end
    false
  end

  # Compute keyword overlap score using word-level matching.
  # Returns [score_ratio, max_matched_keyword_len, matched_count]
  def keyword_score(text_words, keywords, suffix: false, fuzzy: false)
    total = keywords.sum { |k| k.length.to_f }
    return [0.0, 0, 0] if total == 0.0

    matched_weight = 0.0
    max_matched_len = 0
    matched_count = 0
    keywords.each do |kw|
      if word_match?(text_words, kw, suffix: suffix, fuzzy: fuzzy)
        matched_weight += kw.length.to_f
        matched_count += 1
        max_matched_len = kw.length if kw.length > max_matched_len
      end
    end
    [matched_weight / total, max_matched_len, matched_count]
  end

  # Fuzzy substring check for candidate pre-filtering
  def fuzzy_contains?(haystack, keyword)
    return true if haystack.include?(keyword)
    if keyword.length >= 7
      trunc = keyword[0..-2]
      return true if haystack.include?(trunc)
    end
    false
  end

  def match_products_to_migelids
    puts "#{Time.now}: match_products_to_migelids building migelid keyword index..."

    # Build per-language keyword index for each migelid
    # Structure: migel_code -> { migelid, keywords_XX, secondary_XX, all_keywords }
    migelid_items = []
    codes = migel_code_list.dup
    codes.each do |migel_code|
      next unless migel_code.to_s.length > 5  # only migelids, not groups/subgroups
      migelid = Migel::Model::Migelid.find_by_migel_code(migel_code)
      next unless migelid

      item = { migelid: migelid, migel_code: migel_code }

      # Per-language primary keywords (first line) and secondary keywords (additional lines, >= 8 chars)
      %w[de fr it].each do |lang|
        name_text = migelid.name.send(lang).to_s
        full_text = name_text.dup
        if migelid.respond_to?(:migelid_text) && migelid.migelid_text
          mt = migelid.migelid_text.send(lang).to_s
          full_text = "#{full_text}\n#{mt}" unless mt.empty?
        end

        item[:"keywords_#{lang}"] = extract_keywords(name_text)
        item[:"secondary_#{lang}"] = extract_secondary_keywords(full_text)

        # All keywords from full text for broad candidate finding
        all_kw = extract_keywords(full_text)
        if migelid.respond_to?(:subgroup) && migelid.subgroup
          all_kw += extract_keywords(migelid.subgroup.name.send(lang).to_s)
          if migelid.subgroup.respond_to?(:group) && migelid.subgroup.group
            all_kw += extract_keywords(migelid.subgroup.group.name.send(lang).to_s)
          end
        end
        item[:"all_keywords_#{lang}"] = all_kw.uniq
      end

      # Combined all_keywords across all languages for inverted index
      item[:all_keywords] = (
        item[:all_keywords_de] + item[:all_keywords_fr] + item[:all_keywords_it]
      ).uniq

      migelid_items << item unless item[:all_keywords].empty?
    end

    puts "#{Time.now}: match_products_to_migelids indexed #{migelid_items.size} migelids"

    # Build inverted index: keyword -> list of migelid_items indices
    inverted_index = {}
    migelid_items.each_with_index do |item, idx|
      item[:all_keywords].each do |kw|
        (inverted_index[kw] ||= []) << idx
      end
    end
    puts "#{Time.now}: match_products_to_migelids inverted index has #{inverted_index.size} keywords"

    # Now iterate all products and try to match
    matched = 0
    unmatched = 0
    already_linked = 0
    product_count = 0

    all_pharmacodes = begin
      ODBA.cache.index_keys('migel_model_product_pharmacode')
    rescue => e
      puts "#{Time.now}: WARNING could not get pharmacode list: #{e}"
      []
    end

    puts "#{Time.now}: match_products_to_migelids matching #{all_pharmacodes.size} products..."

    all_pharmacodes.each do |pharmacode|
      product = Migel::Model::Product.find_by_pharmacode(pharmacode)
      product = product.first if product.is_a?(Array)
      next unless product
      product_count += 1

      # Skip if already linked to a migelid
      if product.respond_to?(:migelid) && product.migelid
        already_linked += 1
        next
      end

      # Get per-language product descriptions, normalized
      desc_de = normalize_german(product.article_name.send('de').to_s)
      desc_fr = normalize_german(product.article_name.send('fr').to_s)
      desc_it = normalize_german(product.article_name.send('it').to_s)
      combined = "#{desc_de} #{desc_fr} #{desc_it}"
      next if combined.strip.empty?

      # Pre-split into words for word-level matching
      words_de = split_words(desc_de)
      words_fr = split_words(desc_fr)
      words_it = split_words(desc_it)

      # Step 1: Find candidate migelids via inverted index (fuzzy substring pre-filter)
      candidate_indices = Set.new
      inverted_index.each do |keyword, indices|
        if fuzzy_contains?(combined, keyword)
          indices.each { |idx| candidate_indices << idx }
        end
      end
      next if candidate_indices.empty?

      # Step 2: Score each candidate using per-language word-level matching
      best_score = 0.0
      best_max_len = 0
      best_idx = nil

      candidate_indices.each do |idx|
        item = migelid_items[idx]

        # Primary scores (first-line keywords)
        # DE uses suffix + fuzzy matching (German compound words and plural/case)
        # FR/IT use exact word matching only
        score_de, max_de, count_de = keyword_score(words_de, item[:keywords_de], suffix: true, fuzzy: true)
        score_fr, max_fr, count_fr = keyword_score(words_fr, item[:keywords_fr])
        score_it, max_it, count_it = keyword_score(words_it, item[:keywords_it])

        # Secondary bonus: only count if at least 1 primary keyword matched
        _, sec_max_de, sec_count_de = count_de > 0 ?
          keyword_score(words_de, item[:secondary_de], suffix: true, fuzzy: true) : [0.0, 0, 0]
        _, sec_max_fr, sec_count_fr = count_fr > 0 ?
          keyword_score(words_fr, item[:secondary_fr]) : [0.0, 0, 0]
        _, sec_max_it, sec_count_it = count_it > 0 ?
          keyword_score(words_it, item[:secondary_it]) : [0.0, 0, 0]

        # Total count = primary + secondary bonus
        total_de = count_de + sec_count_de
        total_fr = count_fr + sec_count_fr
        total_it = count_it + sec_count_it
        max_len_de = [max_de, sec_max_de].max
        max_len_fr = [max_fr, sec_max_fr].max
        max_len_it = [max_it, sec_max_it].max

        # Pick best-scoring language
        candidates_lang = [
          [score_de, max_len_de, total_de],
          [score_fr, max_len_fr, total_fr],
          [score_it, max_len_it, total_it],
        ]
        lang_best = candidates_lang.max_by { |s, _, _| s }
        lang_score, lang_max_len, lang_count = lang_best

        # Match criteria (from Rust):
        # - 2+ matched keywords: score >= 0.3, max keyword len >= 6
        # - 1 matched keyword: score >= 0.5, keyword len >= 10
        passes = if lang_count >= 2
                   lang_score >= 0.3 && lang_max_len >= 6
                 else
                   lang_score >= 0.5 && lang_max_len >= 10
                 end

        if passes && (lang_score > best_score || (lang_score == best_score && lang_max_len > best_max_len))
          best_score = lang_score
          best_max_len = lang_max_len
          best_idx = idx
        end
      end

      if best_idx
        item = migelid_items[best_idx]
        migelid = item[:migelid]
        migelid.products.push(product) unless migelid.products.any? { |p| p.pharmacode == product.pharmacode }
        product.migelid = migelid
        product.save
        migelid.save
        matched += 1
      else
        unmatched += 1
      end

      if product_count % 10000 == 0
        puts "#{Time.now}: match_products_to_migelids #{product_count} products checked (#{matched} matched, #{unmatched} unmatched, #{already_linked} already linked)"
      end
    end

    puts "#{Time.now}: match_products_to_migelids done. #{product_count} products: #{matched} matched, #{unmatched} unmatched, #{already_linked} already linked"
  end

  # for import groups, subgroups, migelids
  def update(path, language)
    puts "#{Time.now}: update #{path} #{language}"
    # update Group, Subgroup, Migelid data from a csv file
    CSV.readlines(path)[1..-1].each do |row|
      id = row.at(Positions_Nummer).to_s.split('.')
      if(id.empty?)
        id = row.at(Kategorie_Nr).to_s.split('.')
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
    groupcd = id.at(Produktegruppe_Nr)
    begin
      puts "#{Time.now}: update_group #{id} groupcd #{groupcd} #{language}" if id.size < 5
      group = Migel::Model::Group.find_by_code(groupcd) || Migel::Model::Group.new(groupcd)
      unless group
          puts "#{Time.now}: UNABLE to update_group #{id} groupcd #{groupcd} #{language}"
        return
      end
      group.name.send(language.to_s + '=', row.at(Produktegruppe).to_s)
      text = row.at(Beschreibung_Produktegruppe).to_s
      text.tr!("\v", " ")
      text.dup.strip!
      group.update_limitation_text(text, language) unless text.empty?
      group.save
      group
    rescue => error
        0
      end
  end
  def update_subgroup(id, group, row, language)
    subgroupcd = id.at(Limitation_Produktegruppe)
    subgroup = group.subgroups.find{|sg| sg.code == subgroupcd} || begin
      sg = Migel::Model::Subgroup.new(subgroupcd)
      group.subgroups.push sg
      group.save
      sg
    end
    subgroup.group = group
    subgroup.name.send(language.to_s + '=', row.at(Kategorie).to_s)
    if text = row.at(Beschreibung_Kategorie).to_s and !text.empty?
      subgroup.update_limitation_text(text, language)
    end
    subgroup.save
    subgroup
  end
  def update_migelid(id,  subgroup, row, language)
    # take data from csv
    migelidcd = id[2,3].join(".")
    name = row.at(Unterkategorie).to_s
    migelid_text = row.at(Bezeichnung).gsub(/[ \t]+/u, " ")
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
    price = ((row.at(Max_Price).to_s[/\d[\d.]*/u].to_f) * 100).round
    begin
      date = row.at(Revision_Valid_since) ? Date.parse(row.at(Revision_Valid_since)) : nil
    rescue => error
      puts error
      0
    end
    limitation = (row.at(Limitation) == 'L')
    qty = row.at(Menge).to_i
    unit = row.at(Einheit).to_s
    # save instance
    begin
    migelid = subgroup.migelids.find{|mi| mi.respond_to?(:code) &&    mi.code == migelidcd} || begin
      mi = Migel::Model::Migelid.new(migelidcd)
      subgroup.migelids.push mi
      subgroup.save
      mi
    end
  rescue => error
    0
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
    end
    migelid.limitation = limitation
    migelid.qty = qty if qty > 0

    if(id[3] != "00")
      1.upto(3) { |num|
                  begin
        micd =  [id[2], '00', num].join('.')
        if mi = subgroup.migelids.find{|m| m.respond_to?(:code) && m.code == micd}
          migelid.add_migelid(mi)
        end
                rescue => error
#              require 'pry'; binding.pry
                puts "migel #{id} #{group} #{error}"
                0
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
