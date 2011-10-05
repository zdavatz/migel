#! /usr/bin/env ruby
# Migel::Model::ProductSpec -- migel -- 06.09.2011 -- mhatakeyama@ywesee.com

$: << File.expand_path('../../lib', File.dirname(__FILE__))

require 'rspec'
require 'rspec/autorun'
require 'migel/model_super'
require 'migel/model/group'
require 'migel/model/subgroup'
require 'migel/model/migelid'
require 'migel/model/product'
require 'migel/util/multilingual'
require 'odba/drbwrapper'

module Migel
  module Model

describe Product, 'Migel::Model::Product examples' do
  before do
    group_code    = '11'
    subgroup_code = '22'
    migelid_code  = '33.44.5'
    @group = Group.new(group_code)
    @subgroup = Subgroup.new(subgroup_code)
    @migelid = Migelid.new(migelid_code)
    @group.subgroups << @subgroup
    @subgroup.group = @group
    @subgroup.migelids << @migelid
    @migelid.subgroup = @subgroup
    @pharmacode = '1234567'
    @product = Product.new(@pharmacode)
    @migelid.products << @product
    @product.migelid = @migelid
    @product.article_name.de = 'article_name'
    @product.company_name.de = 'company_name'
  end
  it "check default values" do
    @product.pharmacode.should == @pharmacode

    @product.migelid.should == @migelid
    @product.price.should == @migelid.price
    @product.qty.should == @migelid.qty
    @product.unit.should == @migelid.unit
    @product.migel_code.should == @migelid.migel_code
    @product.pointer_descr == @migelid.migel_code
  end
  it "full_description should include article_name and company_name" do
    @product.full_description('de').should == 'article_name company_name'
  end
  it 'to_s should return article_name' do
    @product.to_s.should == 'article_name'
    @product.article_name.should == 'article_name'
    @product.article_name.to_s.should == 'article_name'
    @product.article_name.de.should == 'article_name'
  end
  describe "#localized_name" do
    subject {@product.localized_name('de')}
    it {should == 'article_name'}
  end
  describe "#name_base" do
    subject {@product.name_base}
    it {should == 'article_name'}
  end
  describe "#commercial_forms" do
    subject {@product.commercial_forms}
    it {should == []}
  end
  describe "#inidcation" do
    subject {@product.indication}
    it {should be_nil}
  end
end

  end # Model
end # Migel
