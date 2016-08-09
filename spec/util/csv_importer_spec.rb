#! /usr/bin/env ruby
# encoding: utf-8
# Migel::Util::ImporterSpec -- migel -- 05.10.2011 -- mhatakeyama@ywesee.com
$: << File.expand_path('../../lib', File.dirname(__FILE__))
require 'yaml'
require 'rspec'
require 'rspec/mocks'
require 'spec_helper'
require 'migel/model_super'
require 'migel/model/group'
require 'migel/util/csv_importer'
require 'migel/model'
require 'migel/util/mail'
require 'migel/util/server'
require 'odba'
require 'mail'

module Migel
  module Util
    def set_test_mail
      ::Mail.defaults do
        delivery_method :test
      end
      ::Mail::TestMailer.deliveries.clear
    end

    describe CsvImporter, "CSV file does not exist" do
      before(:each) do
        set_test_mail
        @importer = Migel::Util::CsvImporter.new
      end
      it "import_all_products_from_csv must return false" do
        file_to_import = File.expand_path(File.join(File.dirname(__FILE__), '..', 'data', 'should_not_exist.csv'))
        expect(@importer.import_all_products_from_csv({:filename => file_to_import})).to eq(false)
        report = @importer.report
        expect(report.find{|line| /Total time to update/.match(line)}).not_to eq(nil)
        no_imports = 'Total     0 Migelids (    0 Migelids have products /     0 Migelids have no products)'
        expect(report.find{|line| no_imports.eql?(line)}).to eq(no_imports)
        no_csv_file = 'Read CSV-file: '
        expect(report.find{|line| no_csv_file.eql?(line)}).to eq(no_csv_file)
      end
    end

    describe CsvImporter, "Default options (with non existing file) passed" do
      before(:each) do
        set_test_mail
        @importer = Migel::Util::CsvImporter.new
      end
      it "import_all_products_from_csv must return false" do
        options = {
          :report => true,
          :estimate => true,
          :filename => '/var/www/migel/data/csv/update_migel_bauerfeind.csv2',
        }
        expect(@importer.import_all_products_from_csv(options)).to eq(false)
        report = @importer.report
        expect(report.find{|line| /Total time to update/.match(line)}).not_to eq(nil)
        no_imports = 'Total     0 Migelids (    0 Migelids have products /     0 Migelids have no products)'
        expect(report.find{|line| no_imports.eql?(line)}).to eq(no_imports)
        no_csv_file = 'Read CSV-file: '
        expect(report.find{|line| no_csv_file.eql?(line)}).to eq(no_csv_file)
      end
    end
    MigelTestCode = '05.02.03.00.1'
    VenoTrainCode = '17.01.02.00.1'

    describe CsvImporter, "Examples" do
      before(:each) do
        set_test_mail
        allow(ODBA.cache).to receive(:index_keys).and_return(['migel_code'])
        multilingual = double('multilingual')
        expect(multilingual).to receive(:de=).with('Bauerfeind AG').and_return(nil)
        expect(multilingual).to receive(:fr=).with('Bauerfeind SA').and_return(nil)
        expect(multilingual).to receive(:de=).with('AchilloTrain,titan,rechts,1').and_return(nil)
        expect(multilingual).to receive(:fr=).with('AchilloTrain,titane,droit,1').and_return(nil)
        expect(multilingual).to receive(:save).with(no_args).and_return(nil).never
        product_2244350 = double('product_2244350',
                                 :article_name => multilingual,
                                 :migel_code => MigelTestCode,
                                 :ean_code= => nil,
                                 :pharmacode => '2244350')
        venotrain_names = double('venotrain_names')
        expect(venotrain_names).to receive(:de=).with(any_args).and_return(nil).never
        expect(venotrain_names).to receive(:fr=).with(any_args).and_return(nil).never
        expect(venotrain_names).to receive(:save).with(no_args).and_return(nil).never

        product_with_ean = double('product_with_ean',
                                 :article_name => multilingual,
                                 :migel_code => VenoTrainCode,
                                 :ean_code => '4026358067614',
                                 :ean_code= => nil,
                                  )
        expect(product_with_ean).to receive(:pharmacode).with(no_args).and_return(nil).never
        migelid = double('migelid',
                         :migel_code => MigelTestCode,
                         :delete => true,
                         :products => [product_2244350],
                         :add_product => nil,
                         :save => nil,
                        )
        expect(product_2244350).to receive(:migelid=).and_return(nil)
        expect(product_2244350).to receive(:migelid).and_return(migelid).never
        expect(product_2244350).to receive(:ppub=).with('120.50').and_return(nil)
        expect(product_2244350).to receive(:save).with(no_args).and_return(nil)
        expect(product_2244350).to receive(:ean_code).with(no_args).and_return('4046445108532').at_least(:once)
        expect(product_2244350).to receive(:ean_code=).with("4046445108009").and_return(nil)
        expect(product_2244350).to receive(:ean_code=).with("4046445108532").and_return(nil).never
        expect(product_2244350).to receive(:status=).with("A").and_return(nil)
        expect(product_2244350).to receive(:companyname).and_return(multilingual).twice
        @server = Migel::Util::Server.new
        allow_any_instance_of(DRbObject).to receive(:session).and_return(@server)
        allow(ODBA.cache).to receive(:fetch_named).with('all_products', any_args).and_return( { MigelTestCode => product_2244350, VenoTrainCode => product_with_ean})
        expect(Migel::Model::Migelid).to receive(:find_by_migel_code).with('9999.99.99.99').and_return(nil).once
        expect(Migel::Model::Migelid).to receive(:find_by_migel_code).with(MigelTestCode).and_return(migelid).twice
        expect(Migel::Model::Migelid).to receive(:find_by_migel_code).with(VenoTrainCode).and_return(migelid).once
        group = double('group',
                      :name => 'name',
                      :update_limitation_text => nil,
                      :save => nil
                      )
        allow(Migel::Model::Group).to receive(:find_by_code)
        @importer = Migel::Util::CsvImporter.new
      end
      it "import_all_products_from_csv" do
        file_to_import = File.expand_path(File.join(File.dirname(__FILE__), '..', 'data', 'update_migel_bauerfeind.csv'))
        expect(@importer.import_all_products_from_csv({:filename => file_to_import})).to eq(true)
        report = @importer.report
        expect(report.find{|line| /Total time to update/.match(line)}).not_to eq(nil)
        success = 'Total     4 Migelids (    3 Migelids have products /     1 Migelids have no products)'
        expect(report.find{|line| success.eql?(line)}).to eq(success)
        expected = 'Migelids with products (3)'
        expect(report.find{|line| expected.eql?(line)}).to eq(expected)
        expect(::Mail::TestMailer.deliveries.size).to eq(1)
        expect(::Mail::TestMailer.deliveries.first.to_s).not_to match /RuntimeError/
        expect(::Mail::TestMailer.deliveries.first.to_s.index(expected)).not_to eq nil
      end
    end
  end # Util
end # Migel
