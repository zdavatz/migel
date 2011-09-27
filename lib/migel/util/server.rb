#!/usr/bin/env ruby
# enconding: utf-8
# Migel::Util::Server -- migel -- 26.09.2011 -- mhatakeyama@ywesee.com

require 'sbsm/drbserver'

require 'migel/util/importer'
require 'odba/drbwrapper'

module Migel
  module Util
    class Server < SBSM::DRbServer
      def _admin(src, result, priority=0)
        t = Thread.new {
          Thread.current.abort_on_exception = false
          begin
            response = instance_eval(src)
            str = response.to_s
            result << if(str.length > 200)
              response.class
            else
              str
            end.to_s
          rescue StandardError => error
            result << error.message
            #require 'pp'
            Migel.logger.error('admin') { error.class }
            Migel.logger.error('admin') { error.message }
            Migel.logger.error('admin') { error.backtrace.pretty_inspect }
            error
          end
        }
        t[:source] = src
        t.priority = priority
        @admin_threads.add(t)
        t
      end

      # The following methods are for search
      public
      def group
        ODBA::DRbWrapper.new(Migel::Model::Group)
      end
      def subgroup
        ODBA::DRbWrapper.new(Migel::Model::Subgroup)
      end
      def migelid
        ODBA::DRbWrapper.new(Migel::Model::Migelid)
      end
      def product
        ODBA::DRbWrapper.new(Migel::Model::Product)
      end
      def search_migel_migelid(query, lang)
        # search order
        # 1. Group, Subgroup, Migelid name fulltext search
        # 2. Group, Subgroup, Migelid name prefix search
        search_migelid_fulltext(query, lang) or search_migelid_by_name(query, lang) 
      end
      def sort_select_products(products, sortvalue, reverse = nil)
        products = products.select do |product|
            product.ean_code != nil and product.status != 'I'
          end.sort_by do |item|
          if sortvalue.to_sym == :ppub
            item.ppub.to_f
          else
            item.send(sortvalue).to_s
          end
        end
        if reverse
          products.reverse!
        end
        products
      end
      def search_migel_product_by_migel_code(migel_code, sortvalue = nil, reverse = nil)
        if migelid = Migel::Model::Migelid.search_by_migel_code(migel_code).first and products = migelid.products
          sortvalue ||= :pharmacode
          if products = sort_select_products(products, sortvalue, reverse)
            ODBA::DRbWrapper.new(products)
          end
        end
      end
      private
      def search_migelid_fulltext(query, lang)
        index_table_name = 'migel_fulltext_index_' + lang
        result = ODBA.cache.retrieve_from_index(index_table_name, query)
        ODBA::DRbWrapper.new(result) unless result.empty?
      end
      def search_migelid_by_name(query, lang)
        search_method = 'search_by_name_' + lang
        result = []
        if groups = Migel::Model::Group.send(search_method, query) and !groups.empty?
          groups.each do |group|
            result.concat group.subgroups.collect{|sg| sg.migelids}.flatten
          end
        end
        if subgroups = Migel::Model::Subgroup.send(search_method, query) and !subgroups.empty?
          result.concat subgroups.collect{|sg| sg.migelids}.flatten
        end
        result.concat Migel::Model::Migelid.send(search_method, query)
        ODBA::DRbWrapper.new(result.uniq)
      end

      public
      def search_migel_product(query, lang, sortvalue = nil, reverse = nil)
        # search product by fulltext search
        index_table_name = 'migel_product_fulltext_index_' + lang
        result = ODBA.cache.retrieve_from_index(index_table_name, query)
        products = unless result.empty?
                     result
                   else
                   # search product by name (prefix search)
                     search_method_article_name = 'search_by_article_name_' + lang.downcase.to_s
                     search_method_company_name = 'search_by_company_name_' + lang.downcase.to_s
                     result = Migel::Model::Product.send(search_method_article_name, query) + Migel::Model::Product.send(search_method_company_name, query)
                     result
                   end

        sortvalue ||= :pharmacode
        if products = sort_select_products(products, sortvalue, reverse)
          ODBA::DRbWrapper.new(products)
        end
      end
      def search_limitation(migel_code)
        case migel_code.length
        when 2 # Group
          if group = Migel::Model::Group.find_by_migel_code(migel_code)
            ODBA::DRbWrapper.new(group.limitation_text)
          end
        when 5 # Subgroup
          if subgroup = Migel::Model::Subgroup.find_by_migel_code(migel_code)
             ODBA::DRbWrapper.new(subgroup.limitation_text)
          end
        else # Migelid
          if migelid = Migel::Model::Migelid.find_by_migel_code(migel_code)
             ODBA::DRbWrapper.new(migelid.limitation_text)
          end
        end
      end
     
      # The following methods are for initial setup
      public
      def init_fulltext_index_tables
        init_migelids
        init_products
        rebuild_fulltext_index_tables
      end
      def init_migelids
        clear_migelids
        ODBA.cache.index_keys('migel_model_migelid_migel_code').each do |migel_code|
          migelids.store(migel_code, Migel::Model::Migelid.find_by_migel_code(migel_code))
        end
        migelids.odba_store
      end
      def migelids
         @migelids ||= ODBA.cache.fetch_named('all_migelids', self){
           {} 
         }
      end
      alias :all_migelids :migelids
      def clear_migelids
        migelids.clear
        migelids.odba_store
      end
      def init_products(estimate = false)
        clear_products
        pharmacode_list = ODBA.cache.index_keys('migel_model_product_pharmacode')
        total = pharmacode_list.length
        start_time = Time.now
        pharmacode_list.each_with_index do |pharmacode, i|
          products.store(pharmacode, Migel::Model::Product.find_by_pharmacode(pharmacode))
          puts estimate_time(start_time, total, i+1) if estimate
        end
        products.odba_store
      end
      def products
        @products ||= ODBA.cache.fetch_named('all_products', self){
          {}
         }
      end
      alias :all_products :products
      def clear_products
        products.clear
        products.odba_store
      end
      def rebuild_fulltext_index_table(yaml_index_definition)
        index_name = yaml_index_definition.index_name
        begin
          ODBA.cache.drop_index(index_name)
        rescue
          # do nothing
        end
        ODBA.cache.create_index(yaml_index_definition, Migel)
        source = instance_eval(yaml_index_definition.init_source)
        #puts "source.size: #{source.size}"
        ODBA.cache.fill_index(yaml_index_definition.index_name, source)
      end
      def rebuild_fulltext_index_tables
        # migel_fulltext_index_de
        # migel_fulltext_index_fr
        # migel_product_fulltext_index_de
        # migel_product_fulltext_index_fr
        index_definition_migel_de = YAML.load <<-EOD
--- !ruby/object:ODBA::IndexDefinition 
index_name: 'migel_fulltext_index_de'
origin_klass: 'Migel::Model::Migelid'
target_klass: 'Migel::Model::Migelid'
resolve_search_term: 'full_description(:de)'
resolve_target: ''
resolve_origin: ''
fulltext: true
init_source: 'all_migelids.values'
dictionary: 'german'
EOD

        index_definition_migel_fr = YAML.load <<-EOD
--- !ruby/object:ODBA::IndexDefinition 
index_name: 'migel_fulltext_index_fr'
origin_klass: 'Migel::Model::Migelid'
target_klass: 'Migel::Model::Migelid'
resolve_search_term: 'full_description(:fr)'
resolve_target: ''
resolve_origin: ''
fulltext: true
init_source: 'all_migelids.values'
dictionary: 'french'
EOD

        index_definition_migel_product_de = YAML.load <<-EOD
--- !ruby/object:ODBA::IndexDefinition 
index_name: 'migel_product_fulltext_index_de'
origin_klass: 'Migel::Model::Product'
target_klass: 'Migel::Model::Product'
resolve_search_term: 'full_description(:de)'
resolve_target: ''
resolve_origin: ''
fulltext: true
init_source: 'all_products.values'
dictionary: 'german'
EOD

        index_definition_migel_product_fr = YAML.load <<-EOD
--- !ruby/object:ODBA::IndexDefinition 
index_name: 'migel_product_fulltext_index_fr'
origin_klass: 'Migel::Model::Product'
target_klass: 'Migel::Model::Product'
resolve_search_term: 'full_description(:fr)'
resolve_target: ''
resolve_origin: ''
fulltext: true
init_source: 'all_products.values'
dictionary: 'french'
EOD
        rebuild_fulltext_index_table(index_definition_migel_de)
        rebuild_fulltext_index_table(index_definition_migel_fr)
        rebuild_fulltext_index_table(index_definition_migel_product_de)
        rebuild_fulltext_index_table(index_definition_migel_product_fr)
      end
    end
  end
end
