#! /usr/bin/env ruby
# Migel::Util::ImporterSpec -- migel -- 05.10.2011 -- mhatakeyama@ywesee.com

$: << File.expand_path('../../lib', File.dirname(__FILE__))
require 'yaml'
require 'rspec'
require 'rspec/mocks'
require 'rspec/autorun'
#include RSpec::Mocks::Methods

require 'migel/util/importer'
require 'migel/model'
require 'migel/util/mail'
require 'odba'

module Migel
  module Util

describe Importer, "Examples" do
  before(:each) do
    @importer = Migel::Util::Importer.new
  end
  it "estimate_time should estimate the total calculation time" do
    Time.stub(:now).and_return(3600.0)
    start_time = 0.0
    total = 100
    count = 30
    expected = "30 / 100\tEstimate total: 3.33 [h] It will be done in: 2.33 [h]\n"
    estimate_time(start_time, total, count).should == expected
    count = 60 
    expected = "60 / 100\tEstimate total: 1.67 [h] It will be done in: 40.00 [m]\n"
    estimate_time(start_time, total, count).should == expected
    start_time = 3500.0
    total = 10
    count = 5
    expected = "5 / 10\tEstimate total: 3.33 [m] It will be done in: 1.67 [m]\n"
    estimate_time(start_time, total, count).should == expected
  end
  it "data_object should create Data instance from Switzerland type of date string with '.'" do
    date = '31.12.2011'
    @importer.date_object(date).should == Date.new(2011,12,31)
  end
  it "update_group should update a Group instance when it is found in the database" do
    name  = mock('name', :de= => nil)
    group = mock('group', 
                   :name => name,
                   :update_limitation_text => nil,
                   :save => nil
                  )
    Migel::Model::Group.stub(:find_by_code).and_return(group)

    id  = ['groupcd']
    row = [0,1,'name','limitation text']
    language = 'de'
    @importer.update_group(id, row, language).should == group
  end
  it "update_group should create a Group instance when it is a new group data" do
    name  = mock('name', :de= => nil)
    group = mock('group', 
                   :name => name,
                   :update_limitation_text => nil,
                   :save => nil
                  )
    Migel::Model::Group.stub(:find_by_code)
    Migel::Model::Group.stub(:new).and_return(group)

    id  = ['groupcd']
    row = [0,1,'name','limitation text']
    language = 'de'
    @importer.update_group(id, row, language).should == group
  end
  it "update_subgroup should update a Subgroup instance when it is found in the database" do
    name  = mock('name', :de= => nil)
    subgroup = mock('subgroup', 
                      :code   => 'subgroupcd',
                      :group= => nil,
                      :name   => name,
                      :update_limitation_text => nil,
                      :save   => nil)
    group = mock('group', 
                   :subgroups => [subgroup]
                  )

    row = [0,1,2,3,4,5,'name','limitation text']
    language = 'de'
    id = [0,'subgroupcd']
    @importer.update_subgroup(id, group, row, language).should == subgroup
  end
  it "update_subgroup should create a Subgroup instance when it is not found in the database" do
    group = mock('group', 
                   :subgroups => [],
                   :save => nil
                  )
    name  = mock('name', :de= => nil)
    subgroup = mock('subgroup', 
                      :group= => nil,
                      :name => name,
                      :update_limitation_text => nil,
                      :save => nil
                     )
    Migel::Model::Subgroup.stub(:new).and_return(subgroup)

    id = [0, 'id']
    row = [0,1,2,3,4,5,'name','limitation text']
    language = 'de'
    @importer.update_subgroup(id, group, row, language).should == subgroup
  end
  it "update_migelid should update a Migelid instance when it is found in the database" do
    migelid = mock('migelid', 
                   :subgroup= => nil,
                   :update_multilingual => nil,
                   :code   => '12.34.5',
                   :save   => nil,
                   :type=  => nil,
                   :price= => nil,
                   :date=  => nil,
                   :qty=   => nil,
                   :limitation= => nil
                  )
    name  = mock('name', :de= => nil)
    subgroup = mock('subgroup', 
                      :migelids => [migelid],
                      :group= => nil,
                      :name => name,
                      :update_limitation_text => nil,
                      :save => nil
                     )
    id = [0,1,'12','34','5']
    row = [0,1,2,3,4,5,6,7,8,9,10,11,'name',13,'L','migelid text Limitation text','qty','unit','1234',19,'31.12.2011']
    language = 'de'
    @importer.update_migelid(id, subgroup, row, language).should == migelid
    row = [0,1,2,3,4,5,6,7,8,9,10,11,'',13,'L','migelid text','qty','unit','1234',19,'31.12.2011']
    @importer.update_migelid(id, subgroup, row, language).should == migelid
  end
  it "update_migelid should create a Migelid instance when it is not found in the database" do
    migelid = mock('migelid', 
                   :subgroup= => nil,
                   :update_multilingual => nil,
                   :code   => '12.00.1',
                   :save   => nil,
                   :type=  => nil,
                   :price= => nil,
                   :date=  => nil,
                   :qty=   => nil,
                   :limitation= => nil,
                   :add_migelid => nil
                  )
    name  = mock('name', :de= => nil)
    subgroup = mock('subgroup', 
                      :migelids => [],
                      :group= => nil,
                      :name => name,
                      :update_limitation_text => nil,
                      :save => nil
                     )
    Migel::Model::Migelid.stub(:new).and_return(migelid)
    id = [0,1,'12','34','5']
    row = [0,1,2,3,4,5,6,7,8,9,10,11,'name',13,'L','migelid text Limitation text','qty','unit','1234',19,'31.12.2011']
    language = 'de'
    @importer.update_migelid(id, subgroup, row, language).should == migelid
  end
  describe "update method updates group, subgroup, and migelid instances" do
    before(:each) do
      row = [0,1,2,3,4,5,6,7,8,9,10,11,'name','12.34.56.78.9','L','migelid text Limitation text','qty','unit','1234',19,'31.12.2011']
      CSV.stub(:readlines).and_return([0,row])

      # for migelid
      name  = mock('name', :de= => nil)
      @migelid = mock('migelid', 
                     :subgroup= => nil,
                     :update_multilingual => nil,
                     :code   => '56.78.9',
                     :save   => nil,
                     :type=  => nil,
                     :price= => nil,
                     :date=  => nil,
                     :qty=   => nil,
                     :limitation= => nil,
                     :migel_code  => '12.34.56.78.9',
                     :delete => 'delete_migelid'
                    )
      # for subgroup
      @subgroup = mock('subgroup', 
                        :code   => '34',
                        :group= => nil,
                        :name   => name,
                        :update_limitation_text => nil,
                        :save   => nil,
                        :migelids   => [@migelid],
                        :migel_code => '12.34',
                        :delete => 'delete_subgroup'
                     )
      # for group
      @group = mock('group', 
                     :name => name,
                     :update_limitation_text => nil,
                     :save => nil,
                     :subgroups  => [@subgroup],
                     :migel_code => '12',
                     :delete => 'delete_group'
                    )
      Migel::Model::Group.stub(:find_by_code).and_return(@group)
    end
    it "normal update" do
      ODBA.cache.stub(:index_keys).and_return(['12', '12.34', '12.34.56.78.9'])

      language = 'de'
      lambda do 
        @importer.update('path', language)
      end.should_not raise_error
      @importer.migel_code_list.should == []

      row = [0,1,2,3,4,5,6,7,8,9,10,11,'name','12.34.56.78.9','L','migelid text Limitation text','qty','unit','1234',19,'31.12.2011']
      CSV.stub(:readlines).and_return([0,row])
      row[13] = ''
      row[4]  = '12.34.56.78.9'
      lambda do 
        @importer.update('path', language)
      end.should_not raise_error
    end
    it "delete group" do
      ODBA.cache.stub(:index_keys).and_return(['10', '12.34', '12.34.56.78.9'])
      Migel::Model::Group.stub(:find_by_migel_code).and_return(@group)
      language = 'de'
      @importer.update('path', language)
      @importer.migel_code_list.should == ['10']
    end
    it "delete subgroup" do
      ODBA.cache.stub(:index_keys).and_return(['12', '12.30', '12.34.56.78.9'])
      Migel::Model::Subgroup.stub(:find_by_migel_code).and_return(@subgroup)
      language = 'de'
      @importer.update('path', language)
      @importer.migel_code_list.should == ['12.30']
    end
    it "delete migelid" do
      ODBA.cache.stub(:index_keys).and_return(['12', '12.34', '12.34.56.78.0'])
      Migel::Model::Migelid.stub(:find_by_migel_code).and_return(@migelid)
      language = 'de'
      @importer.update('path', language)
      @importer.migel_code_list.should == ['12.34.56.78.0']
    end
  end
  it "get_products_by_migel_code should search product data from online migel server" do
    server = mock('swissindex_nonpharmad')
    DRbObject.stub(:new).and_return(@server)
    require 'migel/util/swissindex'

    migelid = mock('migelid', :migel_code => '12.34.56.78.9')
    Migel::Model::Migelid.stub(:find_by_migel_code).and_return(migelid)
    record = {:pharmacode => 'pharmacode', :article_name => 'article_name'}
    table = [record]
    Migel::Util::Swissindex.stub(:search_migel_table).and_return(table)

    @importer.get_products_by_migel_code('migel_code').should == table
  end
  it "migel_code_list should return migel_code list of Array" do
    ODBA.cache.stub(:index_keys).and_return(['migel_code'])
    @importer.migel_code_list.should == ['migel_code']
  end
  it "migel_code_list should output migel_code list into a file" do
    ODBA.cache.stub(:index_keys).and_return(['migel_code'])
    file = mock('out', :print => nil)
    File.stub(:open).and_yield(file)
    @importer.migel_code_list('migel_code_list.dat').should == ['migel_code']
  end
  it "unimported_migel_code_list should return uniported migel_code list" do
    ODBA.cache.stub(:index_keys).and_return(['migel_code'])
    migelid = mock('migelid', :products => [])
    Migel::Model::Migelid.stub(:find_by_migel_code).and_return(migelid)
    @importer.unimported_migel_code_list.should == ['migel_code']
  end
  it "unimported_migel_code_list should output unimported migel_code list into a file" do
    ODBA.cache.stub(:index_keys).and_return(['migel_code'])
    migelid = mock('migelid', :products => [])
    Migel::Model::Migelid.stub(:find_by_migel_code).and_return(migelid)
    file = mock('out', :print => nil)
    File.stub(:open).and_yield(file)
    @importer.unimported_migel_code_list('unimported_migel_code_list.dat').should == ['migel_code']
  end
  it "save_all_products should save all the products data into a file" do
    ODBA.cache.stub(:index_keys).and_return(['migel_code'])
    server = mock('swissindex_nonpharmad')
    DRbObject.stub(:new).and_return(@server)
    require 'migel/util/swissindex'
    migelid = mock('migelid', :migel_code => '12.34.56.78.9')
    Migel::Model::Migelid.stub(:find_by_migel_code).and_return(migelid)
    record = {:pharmacode => 'pharmacode', :article_name => 'article_name'}
    table = [record]
    Migel::Util::Swissindex.stub(:search_migel_table).and_return(table)

    writer = mock('writer', :<< => nil)
    CSV.stub(:open).and_yield(writer)

    @importer.save_all_products.should == ['migel_code']
  end
  describe 'update_product example' do
    before(:each) do
      multilingual = mock('multilingual', :de= => nil)
      @product = mock('product', 
                     :pharmacode => 'pharmacode',
                     :migelid=   => nil,
                     :save       => nil,
                     :ean_code=  => nil,
                     :article_name => multilingual,
                     :companyname  => multilingual,
                     :companyean=  => nil,
                     :ppha=      => nil,
                     :ppub=      => nil,
                     :factor=    => nil,
                     :pzr=       => nil,
                     :size       => multilingual,
                     :status=    => nil,
                     :datetime=  => nil,
                     :stdate=    => nil,
                     :language=  => nil
                    )
      @record = {
        :pharmacode   => 'pharmacode',
        :ean_code     => 'ean_code',
        :article_name => 'article_name',
        :companyname  => 'companyname',
        :companyean   => 'companyean',
        :ppha         => 'ppha',
        :ppub         => 'ppub',
        :factor       => 'factor',
        :pzr          => 'pzr',
        :size         => 'size',
        :status       => 'status',
        :datetime     => 'datetime',
        :stdate       => 'stdate',
        :language     => 'language'
      }
      @language = 'de'
      @importer = Migel::Util::Importer.new
    end
    it "update_product should update a Product instance when it is found in the database" do
      migelid = mock('migelid', :products => [@product])
      language = @language
      record = @record
      product = @product
      @importer.instance_eval do 
        update_product(migelid, record, language).should == product
      end
    end
    it "update_product should create a Product instance when it is not found in the database" do
      migelid = mock('migelid', 
                     :products => [],
                     :save     => nil
                    )

      Migel::Model::Product.stub(:new).and_return(@product)
      language = @language
      record = @record
      product = @product
      @importer.instance_eval do 
        update_product(migelid, record, language).should == product
      end
    end
    it "update_products_by_migel_code should update products searched by online migel server" do
      migelid = mock('migelid', 
                     :products => [@product],
                     :migel_code => 'migel_code',
                     :save => nil
                    )
      Migel::Model::Migelid.stub(:find_by_migel_code).and_return(migelid)

      server = mock('swissindex_nonpharmad')
      DRbObject.stub(:new).and_return(@server)
      require 'migel/util/swissindex'
      record = {:pharmacode => 'pharmacode', :article_name => 'article_name'}
      table = [record]
      Migel::Util::Swissindex.stub(:search_migel_table).and_return(table)
    
      @importer.update_products_by_migel_code('migel_code', 'de').should be_nil
    end
    it "import_all_products_from_csv should update products by a csv file" do
      File.stub(:readlines).and_return(['line'])
      line = ['migel_code', 'pharmacode', 'ean_code', 'article_name']
      CSV.stub(:open).and_yield(line)
      migelid = mock('migelid', 
                     :products => [@product],
                     :migel_code => 'migel_code',
                     :save => nil
                    )
      Migel::Model::Migelid.stub(:find_by_migel_code).and_return(migelid)
      product = double('product', :delete => 'delete')
      Migel::Model::Product.stub(:find_by_pharmacode).and_return(product)
      ODBA.cache.stub(:index_keys).and_return(['code'])
      
      @importer.import_all_products_from_csv.should == ['code']
    end
  end
  describe 'missing_article_name_migel_code_list' do
    before(:each) do
      ODBA.cache.stub(:index_keys).and_return(['migel_code'])
      multilingual = mock('multilingual', :de => '')
      product = mock('product', :article_name => multilingual)
      migelid = mock('migelid', :products => [product])
      Migel::Model::Migelid.stub(:find_by_migel_code).and_return(migelid)
    end
    it "missing_article_name_migel_code_list should return missing migel code list" do
      @importer.missing_article_name_migel_code_list.should == ['migel_code']
    end
    it "missing_article_name_migel_code_list should outout missing migel code list" do
      file = mock('out', :print => nil)
      File.stub(:open).and_yield(file)
      @importer.missing_article_name_migel_code_list('de', 'migel_code_list.dat').should == ['migel_code']
    end
  end
  it 'reimport_missing_data should update products' do
    # for missing_article_name_migel_code_list
    ODBA.cache.stub(:index_keys).and_return(['migel_code'])
    multilingual = mock('multilingual', 
                        :de  => '',
                        :de= => nil
                       )
    product = mock('product', 
                   :article_name => multilingual,
                   :pharmacode   => 'pharmacode',
                   :migelid=     => nil,
                   :ean_code=    => nil,
                   :companyname  => multilingual,
                   :companyean=  => nil,
                   :ppha=        => nil,
                   :ppub=        => nil,
                   :factor=      => nil,
                   :pzr=         => nil,
                   :size         => multilingual,
                   :status=      => nil,
                   :datetime=    => nil,
                   :stdate=      => nil,
                   :language=    => nil,
                   :save         => nil
                  )

    # for update_products_by_migel_code
    migelid = mock('migelid', 
                   :products => [product],
                   :migel_code => 'migel_code',
                   :save => nil
                  )
    Migel::Model::Migelid.stub(:find_by_migel_code).and_return(migelid)

    server = mock('swissindex_nonpharmad')
    DRbObject.stub(:new).and_return(@server)
    require 'migel/util/swissindex'
    record = {:pharmacode => 'pharmacode', :article_name => 'article_name'}
    table = [record]
    Migel::Util::Swissindex.stub(:search_migel_table).and_return(table)

    @importer.reimport_missing_data.should == '1 migelids is updated.'

  end
  describe '#code_list' do
    context 'default' do
      before do
        ODBA.cache.stub(:index_keys).and_return(['migel_code'])
      end
      subject {@importer.code_list('index_table_name')}
      it {should == ['migel_code']}
    end
  end
  describe '#migel_code_list' do
    before do
      ODBA.cache.stub(:index_keys).and_return(['migel_code'])
    end
    subject {@importer.migel_code_list}
    it {should == ['migel_code']}
  end
  describe '#report' do
    before do
      ODBA.cache.stub(:index_keys).and_return(['migel_code'])
      @importer.stub(:migel_code_list).and_return(['migel_code'])
      @importer.instance_eval do
        @migel_codes_with_products = []
        @migel_codes_without_products = []
      end
    end
    subject {@importer.report('de')}
    let(:expected) {
      ["Saved file: ",
       "Total     1 Migelids (    0 Migelids have products /     0 Migelids have no products)",
       "Saved  Products",
       "Save time length: ",
       "",
       "Migelids with products (0)",
       "",
       "Migelids without products (0)"]
    }
    it {should == expected}
  end
  describe '#compress' do
    before do
      File.stub(:mtime)
      File.stub(:open)
      @gz = mock('gz', 
                 :mtime= => nil,
                 :orig_name= => nil,
                 :puts => nil
                )
      Zlib::GzipWriter.stub(:open).and_yield(@gz)
    end
    subject {@importer.compress('file')}
    it {should == 'file.gz'}
  end
  describe '#report_save_all_products' do
    before do
      ODBA.cache.stub(:index_keys).and_return(['migel_code'])
      server = mock('swissindex_nonpharmad')
      DRbObject.stub(:new).and_return(@server)
      require 'migel/util/swissindex'
      migelid = mock('migelid', :migel_code => '12.34.56.78.9')
      Migel::Model::Migelid.stub(:find_by_migel_code).and_return(migelid)
      record = {:pharmacode => 'pharmacode', :article_name => 'article_name'}
      table = [record]
      Migel::Util::Swissindex.stub(:search_migel_table).and_return(table)

      writer = mock('writer', :<< => nil)
      CSV.stub(:open).and_yield(writer)

      File.stub(:mtime)
      File.stub(:open)
      @gz = mock('gz', 
                 :mtime= => nil,
                 :orig_name= => nil,
                 :puts => nil
                )
      Zlib::GzipWriter.stub(:open).and_yield(@gz)
      config = mock('config', :server_name => 'server_name')
      Migel.stub(:config).and_return(config)
      Mail.stub(:notify_admins_attached).and_return('notify_admins_attached')
      @importer.stub(:migel_code_list).and_return(['migel_code'])
      @importer.instance_eval do
        @migel_codes_with_products = []
        @migel_codes_without_products = []
      end
    end
    subject {@importer.reported_save_all_products}
    it {should be_a(Array)}
  end
end # describe

  end # Util
end # Migel
