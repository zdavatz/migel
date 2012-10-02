#!/usr/bin/env ruby
# encoding: utf-8
# Migel::Model::Product -- migel -- 30.09.2011 -- mhatakeyama@ywesee.com

module Migel
  module Model
    class Product < Migel::ModelSuper 
      belongs_to :migelid, delegates(:price, :qty, :unit, :migel_code)
      alias :pointer_descr :migel_code 
      attr_accessor :ean_code, :article_name, :companyname, :companyean, :ppha, :ppub, :factor, :pzr, :status, :datetime, :stdate, :language
      attr_reader :pharmacode
      multilingual :article_name
      multilingual :companyname
      multilingual :size
      alias :description :article_name
      alias :name :article_name
      alias :company_name :companyname
      def initialize(pharmacode)
        @pharmacode = pharmacode
      end
      def full_description(lang)
        [(article_name.send(lang) or ''), (companyname and companyname.send(lang) or '')].join(' ')
      end
      def to_s
        name.to_s
      end
      def localized_name(language)
        # This is called from Google button
        # See src/view/additional_information.rb#google_search (oddb.org) 
        self.name.send(language)
      end
      # The following 3 methods, name_base, commercial_forms, indication are called from twitter button
      # See src/view/additional_information.rb#google_search (oddb.org)
      def name_base
        self.name.de
      end
      def commercial_forms
        []
      end
      def indication
        nil
      end
    end
  end
end
