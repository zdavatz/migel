#!/usr/bin/env ruby
# encoding: utf-8
# Migel::Util::Swissindex -- migel -- 07.09.2011 -- mhatakeyama@ywesee.com

require 'migel/ext/swissindex'

module ODDB
  module Swissindex
    class SwissindexNonpharma; end
  end
end

module Migel
  module Util
    module Swissindex
      SWISSINDEX_NONPHARMA_URI = 'druby://localhost:50002'
      SWISSINDEX_NONPHARMA_SERVER = DRbObject.new(nil, SWISSINDEX_NONPHARMA_URI)

class << self
  def search_migel_table(migel_code, lang = 'DE')
    lang.upcase!
    table =  []
    SWISSINDEX_NONPHARMA_SERVER.session(ODDB::Swissindex::SwissindexNonpharma) do |swissindex|
      table = swissindex.search_migel_table(migel_code, 'MiGelCode', lang)
    end
    table
  end
end

    end # Swissindex
  end # Util
end # Migel



