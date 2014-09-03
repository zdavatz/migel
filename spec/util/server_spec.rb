	#! /usr/bin/env ruby
# Migel::Util::ServerSpec -- migel -- 26.09.2011 -- mhatakeyama@ywesee.com

$: << File.expand_path('../../lib', File.dirname(__FILE__))

require 'rspec'
require 'rspec/mocks'
require 'rspec/autorun'
#include RSpec::Mocks::Methods

require 'migel/model'
require 'migel/util/server'
require 'odba'
require 'odba/index_definition'

module Migel
  module Util

describe Server, "Examples" do
  before(:each) do
    @server = Migel::Util::Server.new
  end
  it "group, subgroup, migelid, product should return its Class wrapped by DRbWrapper" do
    @server.group.should == Migel::Model::Group
    @server.subgroup.should == Migel::Model::Subgroup
    @server.migelid.should == Migel::Model::Migelid
    @server.product.should == Migel::Model::Product
  end
  it "search_migelid_fulltext should return a result of ODBA.cache.retrieve_from_index" do
    ODBA.cache.stub(:retrieve_from_index).and_return(['result'])
    @server.instance_eval do
      search_migelid_fulltext('query', 'language').should == ['result']
    end
  end
  it "search_migelid_by_name should a result by searching a name in Group, Subgroup, and Migelid" do
    migelid  = double('migelid')
    subgroup = double('subgroup', :migelids => [migelid])
    group    = double('group', :subgroups => [subgroup])
    method_name = :search_by_name_de
    Migel::Model::Group.stub(method_name).and_return([group])
    Migel::Model::Subgroup.stub(method_name).and_return([subgroup])
    Migel::Model::Migelid.stub(method_name).and_return([migelid])
    expected = [migelid]
    @server.instance_eval do
      search_migelid_by_name('query', 'de').should == expected
    end
  end
  it "search_migel_migelid should return a result of search_migelid_fulltext" do
    ODBA.cache.stub(:retrieve_from_index).and_return(['result'])
    @server.search_migel_migelid('query', 'de').should == ['result']
  end
  it "search_migel_migelid should return a result of search_migelid_by_name" do
    ODBA.cache.stub(:retrieve_from_index).and_return([])
    migelid  = double('migelid')
    subgroup = double('subgroup', :migelids => [migelid])
    group    = double('group', :subgroups => [subgroup])
    method_name = :search_by_name_de
    Migel::Model::Group.stub(method_name).and_return([group])
    Migel::Model::Subgroup.stub(method_name).and_return([subgroup])
    Migel::Model::Migelid.stub(method_name).and_return([migelid])
    expected = [migelid]
    @server.search_migel_migelid('query', 'de').should == expected
  end
  it "search_migel_product should return a result of searching migel_product_fulltext_index_de index table" do
    product = double('product', 
                   :pharmacode => '1',
                   :ean_code => '123',
                   :status   => 'A'
                  )
    ODBA.cache.stub(:retrieve_from_index).and_return([product])
    @server.search_migel_product('query', 'de').should == [product]
  end
  it "search_migel_product should return a result of searching article name and company name of Product" do
    product1 = double('product1', 
                    :pharmacode => '1',
                    :ean_code => '123',
                    :status   => 'A'
                   )
    product2 = double('product2', 
                    :pharmacode => '2',
                    :ean_code => '1234',
                    :status   => 'A'
                   )
    ODBA.cache.stub(:retrieve_from_index).and_return([])
    Migel::Model::Product.should_receive(:search_by_article_name_de).and_return([product1])
    Migel::Model::Product.should_receive(:search_by_company_name_de).and_return([product2])
    @server.search_migel_product('query', 'de').should == [product1, product2]
  end
  it "search_limitation should return a limitation_text instance of Group" do
    group = double('group', :limitation_text => 'limitation_text')
    Migel::Model::Group.stub(:find_by_migel_code).and_return(group)
    @server.search_limitation('11').should == 'limitation_text'
  end
  it "search_limitation should return a limitation_text instance of Subgroup" do
    subgroup = double('subgroup', :limitation_text => 'limitation_text')
    Migel::Model::Subgroup.stub(:find_by_migel_code).and_return(subgroup)
    @server.search_limitation('11.22').should == 'limitation_text'
  end
  it "search_limitation should return a limitation_text instance of Migelid" do
    migelid = double('migelid', :limitation_text => 'limitation_text')
    Migel::Model::Migelid.stub(:find_by_migel_code).and_return(migelid)
    @server.search_limitation('11.22.33.44.5').should == 'limitation_text'
  end
  it "migelids should return fetched @migelids instance variable" do
    ODBA.cache.stub(:fetch_named).and_return({})
    @server.migelids.should == {}
  end
  it "init_migelids should add migelids from index table to @migelids instance variable" do
    ODBA.cache.stub(:fetch_named).and_return({})
    ODBA.cache.stub(:index_keys).and_return(['migel_code'])
    migelid = double('migelid', :migel_code => 'migel_code')
    Migel::Model::Migelid.stub(:find_by_migel_code).and_return(migelid)
    @server.migelids.stub(:odba_store)
    @server.init_migelids
    @server.migelids.should == {'migel_code' => migelid}
  end
  it "clear_migelids should clear @migelids hash variable" do
    ODBA.cache.stub(:fetch_named).and_return({})
    @server.migelids.stub(:odba_store)
    migelid = double('migelid', :migel_code => 'migel_code')
    @server.migelids.store(migelid.migel_code, migelid)
    @server.migelids.should == {'migel_code' => migelid}
    @server.clear_migelids
    @server.migelids.should == {}
  end
  it "products should return fetched @products instance variable" do
    ODBA.cache.stub(:fetch_named).and_return({})
    @server.products.should == {}
  end
  it "init_products should add products from index table to @products instance variable" do
    ODBA.cache.stub(:fetch_named).and_return({})
    ODBA.cache.stub(:index_keys).and_return(['pharmacode'])
    product = double('product', :pharmacode => 'pharmacode')
    Migel::Model::Product.stub(:find_by_pharmacode).and_return(product)
    @server.products.stub(:odba_store)
    @server.init_products
    @server.products.should == {'pharmacode' => product}
  end
  it "clear_products should clear @products hash variable" do
    ODBA.cache.stub(:fetch_named).and_return({})
    @server.products.stub(:odba_store)
    product = double('product', :pharmacode => 'pharmacode')
    @server.products.store(product.pharmacode, product)
    @server.products.should == {'pharmacode' => product}
    @server.clear_products
    @server.products.should == {}
  end
  it "rebuild_fulltext_index_table should build a fulltext index table via ODBA" do
    ODBA.cache.stub(:drop_index)
    ODBA.cache.stub(:create_index)
    ODBA.cache.stub(:fill_index).and_return('fill_index')
    ODBA.cache.stub(:fetch_named).and_return({})
    @server.products.stub(:odba_store)

    index_definition = YAML.load <<-EOD
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

    @server.rebuild_fulltext_index_table(index_definition).should == 'fill_index'
  end
  it "rebuild_fulltext_index_tables should build 4 tables" do
    ODBA.cache.stub(:drop_index)
    ODBA.cache.stub(:create_index)
    ODBA.cache.stub(:fill_index).and_return('fill_index')
    ODBA.cache.stub(:fetch_named).and_return({})
    @server.products.stub(:odba_store)

    lambda do
      @server.rebuild_fulltext_index_tables.should == 'fill_index'
    end.should_not raise_error
  end
  it "rebuild_fulltext_index_table should do nothing if there is no existing table" do
    ODBA.cache.stub(:drop_index).and_raise(RuntimeError)
    ODBA.cache.stub(:create_index)
    ODBA.cache.stub(:fill_index).and_return('fill_index')
    ODBA.cache.stub(:fetch_named).and_return({})
    @server.products.stub(:odba_store)

    index_definition = YAML.load <<-EOD
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

    lambda do
      @server.rebuild_fulltext_index_table(index_definition).should == 'fill_index'
    end.should_not raise_error
  end
  it "_admin should return method result in the argument 'result' (Array)" do
    result = []
    @server._admin('self.class', result)
    result.should == ['Migel::Util::Server']
    result = []
    @server._admin('"a"*201', result)
    result.should == ['String']
  end
  it "_admin should return error message when StandardError happens during the method execution" do
    result = []
    @server._admin('Server.hogehoge', result)
    result.should == ["undefined method `hogehoge' for Migel::Util::Server:Class"]
  end
  it "init_fulltext_index_tables should raise nothing" do
    ODBA.cache.stub(:fetch_named).and_return({})
    ODBA.cache.stub(:index_keys).and_return(['code'])
    ODBA.cache.stub(:drop_index)
    ODBA.cache.stub(:create_index)
    ODBA.cache.stub(:fill_index).and_return('fill_index')
    @server.migelids.stub(:odba_store)
    migelid = double('migelid', :migel_code => 'migel_code')
    product = double('product', :pharmacode => 'pharmacode')
    Migel::Model::Migelid.stub(:find_by_migel_code).and_return(migelid)
    Migel::Model::Product.stub(:find_by_pharmacode).and_return(product)

    lambda do 
      @server.init_fulltext_index_tables
    end.should_not raise_error
  end
  it "sort_select_products should select products" do
    product1 = double('product1', 
                    :pharmacode => '1',
                    :ean_code => nil,
                    :status   => 'A'
                   )
    product2 = double('product2', 
                    :pharmacode => '2',
                    :ean_code => '1234',
                    :status   => 'I'
                   )
    product3 = double('product3', 
                    :pharmacode => '3',
                    :ean_code => '1234',
                    :status   => 'A'
                   )
    products = [product1, product2, product3]
    @server.sort_select_products(products, :pharmacode).should == [product3]
  end
  it "sort_select_products should sort products" do
    product1 = double('product1', 
                    :pharmacode => '1',
                    :ean_code => '123',
                    :status   => 'A',
                    :ppub     => '12.34'
                   )
    product2 = double('product2', 
                    :pharmacode => '2',
                    :ean_code => '1234',
                    :status   => 'A',
                    :ppub     => '12.33'
                   )
    product3 = double('product3', 
                    :pharmacode => '3',
                    :ean_code => '1234',
                    :status   => 'A',
                    :ppub     => '12.32'
                   )
    products = [product2, product1, product3]
    @server.sort_select_products(products, :pharmacode).should == [product1, product2, product3]
    @server.sort_select_products(products, :pharmacode, :reverse).should == [product3, product2, product1]
    @server.sort_select_products(products, :ppub).should == [product3, product2, product1]
  end
  it "search_migel_product_by_migel_code should search products by migel_code" do
    product = double('product', 
                   :pharmacode => '1',
                   :ean_code => '123',
                   :status   => 'A'
                  )
    migelid = double('migelid', :products => [product])
    Migel::Model::Migelid.should_receive(:search_by_migel_code).at_least(1).and_return([migelid])
    @server.search_migel_product_by_migel_code('migel_code').should == [product]
    @server.search_migel_product_by_migel_code('migel_code', :ean_code).should == [product]
    @server.search_migel_product_by_migel_code('migel_code', :ean_code, :reverse).should == [product]
  end
end

  end # Util
end # Migel
