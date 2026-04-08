#! /usr/bin/env ruby
# encoding: utf-8
# Migel::Util::ImporterSpec -- migel -- 05.10.2011 -- mhatakeyama@ywesee.com
$: << File.expand_path('../../lib', File.dirname(__FILE__))
require 'yaml'
require 'rspec'
require 'rspec/mocks'
require 'spec_helper'
require 'migel/util/importer'
require 'migel/model'
require 'migel/util/mail'
require 'odba'
require 'mail'

module Migel
  module Util

describe Importer, "Examples" do
  before(:each) do
    @importer = Migel::Util::Importer.new
  end
  it "estimate_time should estimate the total calculation time" do
    allow(Time).to receive(:now).and_return(3600.0)
    start_time = 0.0
    total = 100
    count = 30
    expected = " 30 / 100\tEstimate total: 3.33 [h] It will be done in: 2.33 [h]\n"
    expect(estimate_time(start_time, total, count)).to eq(expected)
    count = 60
    expected = " 60 / 100\tEstimate total: 1.67 [h] It will be done in: 40.00 [m]\n"
    expect(estimate_time(start_time, total, count)).to eq(expected)
    start_time = 3500.0
    total = 10
    count = 5
    expected = "  5 / 10\tEstimate total: 3.33 [m] It will be done in: 1.67 [m]\n"
    expect(estimate_time(start_time, total, count)).to eq(expected)
  end
  it "update_group should update a Group instance when it is found in the database" do
    name  = double('name', :de= => nil)
    group = double('group',
                   :name => name,
                   :update_limitation_text => nil,
                   :save => nil
                  )
    allow(Migel::Model::Group).to receive(:find_by_code).and_return(group)

    id  = ['groupcd']
    row = [0,1,'name','limitation text']
    language = 'de'
    expect(@importer.update_group(id, row, language)).to eq(group)
  end
  it "update_group should create a Group instance when it is a new group data" do
    name  = double('name', :de= => nil)
    group = double('group',
                   :name => name,
                   :update_limitation_text => nil,
                   :save => nil
                  )
    allow(Migel::Model::Group).to receive(:find_by_code)
    allow(Migel::Model::Group).to receive(:new).and_return(group)

    id  = ['groupcd']
    row = [0,1,'name','limitation text']
    language = 'de'
    expect(@importer.update_group(id, row, language)).to eq(group)
  end
  it "update_subgroup should update a Subgroup instance when it is found in the database" do
    name  = double('name', :de= => nil)
    subgroup = double('subgroup',
                      :code   => 'subgroupcd',
                      :group= => nil,
                      :name   => name,
                      :update_limitation_text => nil,
                      :save   => nil)
    group = double('group',
                   :subgroups => [subgroup]
                  )

    row = [0,1,2,3,4,5,'name','limitation text']
    language = 'de'
    id = [0,'subgroupcd']
    expect(@importer.update_subgroup(id, group, row, language)).to eq(subgroup)
  end
  it "update_subgroup should create a Subgroup instance when it is not found in the database" do
    group = double('group',
                   :subgroups => [],
                   :save => nil
                  )
    name  = double('name', :de= => nil)
    subgroup = double('subgroup',
                      :group= => nil,
                      :name => name,
                      :update_limitation_text => nil,
                      :save => nil
                     )
    allow(Migel::Model::Subgroup).to receive(:new).and_return(subgroup)

    id = [0, 'id']
    row = [0,1,2,3,4,5,'name','limitation text']
    language = 'de'
    expect(@importer.update_subgroup(id, group, row, language)).to eq(subgroup)
  end
  it "update_migelid should update a Migelid instance when it is found in the database" do
    migelid = double('migelid',
                   :subgroup= => nil,
                   :update_multilingual => nil,
                   :code   => '12.34.5',
                   :date   => nil,
                   :save   => nil,
                   :type=  => nil,
                   :price= => nil,
                   :date=  => nil,
                   :qty=   => nil,
                   :limitation= => nil,
                   :limitation_text => nil,
                  )
    name  = double('name', :de= => nil)
    subgroup = double('subgroup',
                      :migelids => [migelid],
                      :group= => nil,
                      :name => name,
                      :update_limitation_text => nil,
                      :save => nil
                     )
    id = [0,1,'12','34','5']
    row = [0,1,2,3,4,5,6,7,8,9,10,11,'name',13,'L','migelid text Limitation text','qty','unit','1234',19,'31.12.2011']
    language = 'de'
    expect(@importer.update_migelid(id, subgroup, row, language)).to eq(migelid)
    row = [0,1,2,3,4,5,6,7,8,9,10,11,'',13,'L','migelid text','qty','unit','1234',19,'31.12.2011']
    expect(@importer.update_migelid(id, subgroup, row, language)).to eq(migelid)
  end
  it "update_migelid should create a Migelid instance when it is not found in the database" do
    migelid = double('migelid',
                   :subgroup= => nil,
                   :update_multilingual => nil,
                   :code   => '12.00.1',
                   :date   => nil,
                   :save   => nil,
                   :type=  => nil,
                   :price= => nil,
                   :date=  => nil,
                   :qty=   => nil,
                   :limitation= => nil,
                   :limitation_text => nil,
                   :add_migelid => nil
                  )
    name  = double('name', :de= => nil)
    subgroup = double('subgroup',
                      :migelids => [],
                      :group= => nil,
                      :name => name,
                      :update_limitation_text => nil,
                      :save => nil
                     )
    allow(Migel::Model::Migelid).to receive(:new).and_return(migelid)
    id = [0,1,'12','34','5']
    row = [0,1,2,3,4,5,6,7,8,9,10,11,'name',13,'L','migelid text Limitation text','qty','unit','1234',19,'31.12.2011']
    language = 'de'
    expect(@importer.update_migelid(id, subgroup, row, language)).to eq(migelid)
  end
  describe "update method updates group, subgroup, and migelid instances" do
    before(:each) do
      row = [0,1,2,3,4,5,6,7,8,9,10,11,'name',nil,nil,'12.34.56.78.9','L','migelid text Limitation text','qty','unit','1234',nil,'31.12.2011']
      allow(CSV).to receive(:readlines).and_return([0,row])

      # for migelid
      name  = double('name', :de= => nil)
      @migelid = double('migelid',
                     :subgroup= => nil,
                     :update_multilingual => nil,
                     :code   => '56.78.9',
                     :save   => nil,
                     :type=  => nil,
                     :price= => nil,
                     :date=  => nil,
                     :qty=   => nil,
                     :date   => nil,
                     :limitation= => nil,
                     :migel_code  => '12.34.56.78.9',
                     :delete => 'delete_migelid',
                     :limitation_text => nil,
                    )
      # for subgroup
      @subgroup = double('subgroup',
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
      @group = double('group',
                     :name => name,
                     :update_limitation_text => nil,
                     :save => nil,
#                      :subgroups  => [@subgroup.is_a?(Integer) ? nil : @subgoup ],
                     :subgroups  => [@subgroup ],
                     :migel_code => '12',
                     :delete => 'delete_group'
                    )
      allow(Migel::Model::Group).to receive(:find_by_code).and_return(@group)
      allow_any_instance_of(Integer).to receive(:subroups).and_return(nil)
    end
    it "normal update" do
      allow(ODBA.cache).to receive(:index_keys).and_return(['12', '12.34', '12.34.56.78.9'])

      language = 'de'
      expect do
        @importer.update('path', language)
      end.not_to raise_error
      expect(@importer.migel_code_list).to eq([])

      row = [0,1,2,3,4,5,6,7,8,9,10,11,'name',nil,nil,'12.34.56.78.9','L','migelid text Limitation text','qty','unit','1234',nil,'31.12.2011']
      allow(CSV).to receive(:readlines).and_return([0,row])
      row[15] = ''
      row[4]  = '12.34.56.78.9'
      expect do
        @importer.update('path', language)
      end.not_to raise_error
    end
    it "delete group" do
      allow(ODBA.cache).to receive(:index_keys).and_return(['10', '12.34', '12.34.56.78.9'])
      allow(Migel::Model::Group).to receive(:find_by_migel_code).and_return(@group)
      language = 'de'
      @importer.update('path', language)
      expect(@importer.migel_code_list).to eq(['10'])
    end
    it "delete subgroup" do
      allow(ODBA.cache).to receive(:index_keys).and_return(['12', '12.30', '12.34.56.78.9'])
      allow(Migel::Model::Group).to receive(:find_by_migel_code).and_return(@subgroup)
      allow(Migel::Model::Subgroup).to receive(:find_by_migel_code).and_return(nil)
      allow(Migel::Model::Migelid).to receive(:find_by_migel_code).and_return(nil)
      language = 'de'
      @importer.update('path', language)
      expect(@importer.migel_code_list).to eq(['12.30'])
    end
    it "delete migelid" do
      allow(ODBA.cache).to receive(:index_keys).and_return(['12', '12.34', '12.34.56.78.0'])
      allow(Migel::Model::Migelid).to receive(:find_by_migel_code).and_return(@migelid)
      language = 'de'
      @importer.update('path', language)
      expect(@importer.migel_code_list).to eq(['12.34.56.78.0'])
    end
  end
  it "migel_code_list should return migel_code list of Array" do
    allow(ODBA.cache).to receive(:index_keys).and_return(['migel_code'])
    expect(@importer.migel_code_list).to eq(['migel_code'])
  end
  it "migel_code_list should output migel_code list into a file" do
    allow(ODBA.cache).to receive(:index_keys).and_return(['migel_code'])
    file = double('out', :print => nil)
    allow(File).to receive(:open).and_yield(file)
    expect(@importer.migel_code_list('migel_code_list.dat')).to eq(['migel_code'])
  end
  it "unimported_migel_code_list should return uniported migel_code list" do
    allow(ODBA.cache).to receive(:index_keys).and_return(['migel_code'])
    migelid = double('migelid',:products => [])
    allow(Migel::Model::Migelid).to receive(:find_by_migel_code).and_return(migelid)
    expect(@importer.unimported_migel_code_list).to eq(['migel_code'])
  end
  it "unimported_migel_code_list should output unimported migel_code list into a file" do
    allow(ODBA.cache).to receive(:index_keys).and_return(['migel_code'])
    migelid = double('migelid',:products => [])
    allow(Migel::Model::Migelid).to receive(:find_by_migel_code).and_return(migelid)
    file = double('out', :print => nil)
    allow(File).to receive(:open).and_yield(file)
    expect(@importer.unimported_migel_code_list('unimported_migel_code_list.dat')).to eq(['migel_code'])
  end
  describe 'update_product example' do
    before(:each) do
      multilingual = double('multilingual', :de= => nil)
      @product = double('product',
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
      migelid = double('migelid',:products => [@product])
      language = @language
      record = @record
      product = @product
      expect(@importer.send(:update_product, migelid, record, language)).to eql product
    end
    it "update_product should create a Product instance when it is not found in the database" do
      migelid = double('migelid',
                     :products => [],
                     :save     => nil
                    )

      allow(Migel::Model::Product).to receive(:new).and_return(@product)
      language = @language
      record = @record
      product = @product
      expect(@importer.send(:update_product, migelid, record, language)).to eql product
    end
    it "update_products_by_migel_code should update products searched by online migel server" do
      migelid = double('migelid',
                     :products => [@product],
                     :migel_code => 'migel_code',
                     :date => nil,
                     :save => nil,
                    )
      allow(Migel::Model::Migelid).to receive(:find_by_migel_code).and_return(migelid)

      server = double('swissindex_nonpharmad')
      allow(DRbObject).to receive(:new).and_return(@server)
      require 'migel/ext/swissindex'
      record = {:pharmacode => 'pharmacode', :article_name => 'article_name'}
      table = [record]
      allow(ODDB::Swissindex).to receive(:search_migel_table).and_return(table)

      expect(@importer.update_products_by_migel_code('migel_code', 'de')).to be_nil
    end
    it "import_all_products_from_csv should update products by a csv file" do
      allow(File).to receive(:readlines).and_return(['line'])
      line = ['migel_code', 'pharmacode', 'ean_code', 'article_name']
      allow(CSV).to receive(:open).and_yield(line)
      migelid = double('migelid',
                     :migel_code => 'migel_code',
                     :add_product => @product,
                     :save => nil,
                     :products => [@product],
                     :date => nil,
                    )
      migelid2 = double('migelid2',
                     :migel_code => 'migel_code',
                     :add_product => @product,
                     :save => nil,
                     :delete => nil,
                     :products => [@product],
                     :date => nil,
                    )
      allow(migelid).to receive(:dup).with(no_args).and_return(migelid2)
      allow(@product).to receive(:delete)
      allow(Migel::Model::Migelid).to receive(:find_by_migel_code).and_return(migelid)
      allow(Migel::Model::Product).to receive(:find_by_pharmacode).and_return(@product)
      allow(ODBA.cache).to receive(:index_keys).and_return(['code'])
      expect(@importer.import_all_products_from_csv).to eq(['code'])
    end
  end
  describe 'missing_article_name_migel_code_list' do
    before(:each) do
      allow(ODBA.cache).to receive(:index_keys).and_return(['migel_code'])
      multilingual = double('multilingual', :de => '')
      product = double('product',:article_name => multilingual)
      migelid = double('migelid',:products => [product])
      allow(Migel::Model::Migelid).to receive(:find_by_migel_code).and_return(migelid)
    end
    it "missing_article_name_migel_code_list should return missing migel code list" do
      expect(@importer.missing_article_name_migel_code_list).to eq(['migel_code'])
    end
    it "missing_article_name_migel_code_list should outout missing migel code list" do
      file = double('out', :print => nil)
      allow(File).to receive(:open).and_yield(file)
      expect(@importer.missing_article_name_migel_code_list('de', 'migel_code_list.dat')).to eq(['migel_code'])
    end
  end
  it 'reimport_missing_data should update products' do
    # for missing_article_name_migel_code_list
    allow(ODBA.cache).to receive(:index_keys).and_return(['migel_code'])
    multilingual = double('multilingual',
                        :de  => '',
                        :de= => nil
                       )
    product = double('product',
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
    migelid = double('migelid',
                   :products => [product],
                   :migel_code => 'migel_code',
                   :date => nil,
                   :save => nil
                  )
    allow(Migel::Model::Migelid).to receive(:find_by_migel_code).and_return(migelid)

    server = double('swissindex_nonpharmad')
    allow(DRbObject).to receive(:new).and_return(@server)
    require 'migel/ext/swissindex'
    record = {:pharmacode => 'pharmacode', :article_name => 'article_name'}
    table = [record]
    allow(ODDB::Swissindex).to receive(:search_migel_table).and_return(table)

    expect(@importer.reimport_missing_data).to eq('1 migelids is updated.')

  end
  describe '#code_list' do
    context 'default' do
      before do
        allow(ODBA.cache).to receive(:index_keys).and_return(['migel_code'])
      end
      subject {@importer.code_list('index_table_name')}
      it {is_expected.to eq(['migel_code'])}
    end
  end
  describe '#migel_code_list' do
    before do
      allow(ODBA.cache).to receive(:index_keys).and_return(['migel_code'])
    end
    subject {@importer.migel_code_list}
    it {is_expected.to eq(['migel_code'])}
  end
  describe '#report' do
    before do
      allow(ODBA.cache).to receive(:index_keys).and_return(['migel_code'])
      allow(@importer).to receive(:migel_code_list).and_return(['migel_code'])
      @importer.instance_eval do
        @migel_codes_with_products = []
        @migel_codes_without_products = []
      end
    end
    subject {@importer.report('de')}
    let(:expected) {
      ["Total time to update: 0.00 [m]",
       "Saved file: ",
       "Total     1 Migelids (    0 Migelids have products /     0 Migelids have no products)",
       "Saved  Products", "",
       "Migelids with products (0)", "",
       "Migelids without products (0)"]
    }
    it {is_expected.to eq(expected)}
  end
  describe '#compress' do
    before do
      allow(File).to receive(:mtime)
      allow(File).to receive(:open)
      @gz = double('gz',
                 :mtime= => nil,
                 :orig_name= => nil,
                 :puts => nil
                )
      allow(Zlib::GzipWriter).to receive(:open).and_yield(@gz)
    end
    subject {@importer.compress('file')}
    it {is_expected.to eq('file.gz')}
  end
  describe '#report_save_all_products' do
    before do
      allow(ODBA.cache).to receive(:index_keys).and_return(['migel_code'])
      server = double('swissindex_nonpharmad')
      allow(DRbObject).to receive(:new).and_return(@server)
      require 'migel/ext/swissindex'
      migelid = double('migelid',:migel_code => '12.34.56.78.9')
      allow(Migel::Model::Migelid).to receive(:find_by_migel_code).and_return(migelid)
      record = {:pharmacode => 'pharmacode', :article_name => 'article_name'}
      table = [record]
      allow(ODDB::Swissindex).to receive(:search_migel_table).and_return(table)

      writer = double('writer', :<< => nil)
      allow(CSV).to receive(:open).and_yield(writer)

      allow(File).to receive(:mtime)
      allow(File).to receive(:open)
      @gz = double('gz',
                 :mtime= => nil,
                 :orig_name= => nil,
                 :puts => nil
                )
      allow(Zlib::GzipWriter).to receive(:open).and_yield(@gz)
      config = double('config', :server_name => 'server_name')
      allow(Migel).to receive(:config).and_return(config)
      allow(Mail).to receive(:notify_admins_attached).and_return('notify_admins_attached')
      allow(@importer).to receive(:migel_code_list).and_return(['migel_code'])
      @importer.instance_eval do
        @migel_codes_with_products = []
        @migel_codes_without_products = []
      end
    end
    subject {@importer.reported_save_all_products}
    it {is_expected.to be_a(Array)}
    subject {@importer.report('de')}
    let(:expected) {
      ["Total time to update: 0.00 [m]",
       "Saved file: ",
       "Total     1 Migelids (    0 Migelids have products /     0 Migelids have no products)",
       "Saved  Products", "",
       "Migelids with products (0)", "",
       "Migelids without products (0)"]
    }
    it {is_expected.to eq(expected)}
  end
end # describe

  describe 'RealWorld: update_all from BAG XLSX' do
    before(:each) do
      allow(ODBA.cache).to receive(:index_keys).and_return(['migel_code'])
      multilingual = double('multilingual', :de => '')
      product = double('product',:article_name => multilingual)
      migelid = double('migelid',:products => [product])
      allow(Migel::Model::Migelid).to receive(:find_by_migel_code).and_return(migelid)
    end

    def setup_importer
      @importer = Migel::Util::Importer.new
      @server = Migel::Util::Server.new
      allow_any_instance_of(DRbObject).to receive(:session).and_return(@server)
      migelid = double('migelid',:migel_code => '12.34.56.78.9', :delete => true)
      allow(Migel::Model::Migelid).to receive(:find_by_migel_code).and_return(migelid)
      group = double('group',
                    :name => 'name',
                    :update_limitation_text => nil,
                    :save => nil
                    )
      allow(Migel::Model::Group).to receive(:find_by_code)
      expect(@importer.data_dir).not_to be_nil
    end

    def create_test_xlsx(path)
      book = RubyXL::Workbook.new
      # RubyXL creates a default sheet; rename it and add two more
      sheet_de = book.worksheets[0]
      sheet_de.sheet_name = 'MiGeL D'
      sheet_fr = book.add_worksheet('MiGeL F')
      sheet_it = book.add_worksheet('MiGeL I')

      # Add a group row, subgroup row, and position row to each sheet
      [sheet_de, sheet_fr, sheet_it].each do |sheet|
        # Row 0: header (skipped by importer)
        sheet.add_cell(0, 0, 'Produktegruppe')

        # Row 1: Group header — col 0 = group code, col 9 = name
        sheet.add_cell(1, 0, '01')
        sheet.add_cell(1, 9, 'Testgruppe')

        # Row 2: Subgroup header — col 1 = subgroup code, col 9 = name
        sheet.add_cell(2, 1, '01.01')
        sheet.add_cell(2, 9, 'Testsubgruppe')

        # Row 3: Position — col 7 = pos_nr, col 9 = bezeichnung, col 12 = price, col 14 = date
        sheet.add_cell(3, 7, '01.01.01.00.1')
        sheet.add_cell(3, 9, "Testprodukt\nDetailtext")
        sheet.add_cell(3, 11, '1 Stk')
        sheet.add_cell(3, 12, 50.0)
        sheet.add_cell(3, 14, '01.10.2021')
      end

      book.write(path)
    end

    def setup_xlsx_stubbing
      # Create a test XLSX file
      @test_xlsx = File.join(@importer.send(:instance_variable_get, :@xlsx_dir), 'test_migel.xlsx')
      create_test_xlsx(@test_xlsx)
      test_content = File.read(@test_xlsx, mode: 'rb')

      # Stub URI.open to return the test XLSX content (fresh StringIO each call)
      allow(URI).to receive(:open).with(Migel::Util::Importer::BAG_XLSX_URL) { |_, &blk| blk.call(StringIO.new(test_content)) }

      # Remove the latest file so update_all doesn't skip
      xlsx_dir = @importer.send(:instance_variable_get, :@xlsx_dir)
      latest = File.join(xlsx_dir, 'MiGeL_BAG-latest.xlsx')
      FileUtils.rm_f(latest)
    end

    it "update_all should process BAG XLSX and call model updates" do
      setup_importer
      setup_xlsx_stubbing

      # Set up model stubs to track calls
      name_dbl = double('name')
      allow(name_dbl).to receive(:de=)
      allow(name_dbl).to receive(:fr=)
      allow(name_dbl).to receive(:it=)
      subgroup_dbl = double('subgroup',
                            :code => '01',
                            :name => name_dbl,
                            :group= => nil,
                            :update_limitation_text => nil,
                            :save => nil,
                            :migelids => [],
                            :migel_code => '01.01'
                           )
      group_dbl = double('group',
                        :code => '01',
                        :name => name_dbl,
                        :update_limitation_text => nil,
                        :save => nil,
                        :subgroups => [subgroup_dbl],
                        :migel_code => '01'
                        )
      allow(Migel::Model::Group).to receive(:find_by_code).and_return(group_dbl)
      allow(Migel::Model::Group).to receive(:new).and_return(group_dbl)

      migelid_dbl = double('migelid',
                           :code => '01.00.1',
                           :subgroup= => nil,
                           :name => name_dbl,
                           :migelid_text => name_dbl,
                           :save => nil,
                           :migel_code => '01.01.01.00.1'
                          )
      allow(migelid_dbl).to receive(:limitation_text).with(any_args).and_return(name_dbl)
      allow(migelid_dbl).to receive(:update_multilingual)
      allow(migelid_dbl).to receive(:price=)
      allow(migelid_dbl).to receive(:qty=)
      allow(migelid_dbl).to receive(:date=)
      allow(migelid_dbl).to receive(:limitation=)
      allow(subgroup_dbl).to receive(:migelids).and_return([migelid_dbl])

      @importer.update_all

      # Verify the XLSX was processed (latest file should exist now)
      xlsx_dir = @importer.send(:instance_variable_get, :@xlsx_dir)
      latest = File.join(xlsx_dir, 'MiGeL_BAG-latest.xlsx')
      expect(File.exist?(latest)).to be true

      # Second call should skip (unchanged)
      @importer.update_all

      # Clean up
      FileUtils.rm_f(latest)
      FileUtils.rm_f(@test_xlsx)
    end

    it "save_all_products_all_languages should work fine and send a correct email"  do
      setup_importer
      ::Mail.defaults do
        delivery_method :test
      end
      ::Mail::TestMailer.deliveries.clear
      @importer.save_all_products_all_languages
      expect(::Mail::TestMailer.deliveries.size).to eq(3)
      ::Mail::TestMailer.deliveries.each{ |mail| expect(mail.to_s).not_to match /RuntimeError/ }
    end

    it "update_all should process all 3 language sheets" do
      setup_importer
      setup_xlsx_stubbing

      name_dbl = double('name')
      allow(name_dbl).to receive(:de=)
      allow(name_dbl).to receive(:fr=)
      allow(name_dbl).to receive(:it=)
      subgroup_dbl = double('subgroup',
                            :code => '01',
                            :name => name_dbl,
                            :group= => nil,
                            :update_limitation_text => nil,
                            :save => nil,
                            :migelids => [],
                            :migel_code => '01.01'
                           )
      group_dbl = double('group',
                        :code => '01',
                        :name => name_dbl,
                        :update_limitation_text => nil,
                        :save => nil,
                        :subgroups => [subgroup_dbl],
                        :migel_code => '01'
                        )
      allow(Migel::Model::Group).to receive(:find_by_code).and_return(group_dbl)
      allow(Migel::Model::Group).to receive(:new).and_return(group_dbl)

      migelid_dbl = double('migelid',
                           :code => '01.00.1',
                           :subgroup= => nil,
                           :name => name_dbl,
                           :migelid_text => name_dbl,
                           :save => nil,
                           :migel_code => '01.01.01.00.1'
                          )
      allow(migelid_dbl).to receive(:limitation_text).with(any_args).and_return(name_dbl)
      allow(migelid_dbl).to receive(:update_multilingual)
      allow(migelid_dbl).to receive(:price=)
      allow(migelid_dbl).to receive(:qty=)
      allow(migelid_dbl).to receive(:date=)
      allow(migelid_dbl).to receive(:limitation=)
      allow(subgroup_dbl).to receive(:migelids).and_return([migelid_dbl])

      # Expect update_from_bag_sheet to be called for each language
      expect(@importer).to receive(:update_from_bag_sheet).exactly(3).times.and_call_original
      @importer.update_all

      # Clean up
      xlsx_dir = @importer.send(:instance_variable_get, :@xlsx_dir)
      FileUtils.rm_f(File.join(xlsx_dir, 'MiGeL_BAG-latest.xlsx'))
      FileUtils.rm_f(@test_xlsx)
    end
  end

  end # Util
end # Migel
