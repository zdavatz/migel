#! /usr/bin/env ruby
# Migel::Model::MigelidSpec -- migel -- 09.09.2011 -- mhatakeyama@ywesee.com

$: << File.expand_path('../../lib', File.dirname(__FILE__))

require 'rspec'
require 'rspec/autorun'
require 'migel/model_super'
require 'migel/model/group'
require 'migel/model/subgroup'
require 'migel/model/migelid'
require 'migel/util/multilingual'
require 'odba/drbwrapper'

module Migel
  module Model

group_code    = '11'
subgroup_code = '22'
migelid_code  = '33.44.5'
describe Migelid, "when initialized with code #{migelid_code} (group_code: #{group_code}, subgroup_code: #{subgroup_code})" do
  before do
    @group = Group.new(group_code)
    @subgroup = Subgroup.new(subgroup_code)
    @migelid = Migelid.new(migelid_code)
    @group.subgroups << @subgroup
    @subgroup.group = @group
    @subgroup.migelids << @migelid
    @migelid.subgroup = @subgroup

    @group.name.de = 'group'
    @subgroup.name.de = 'subgroup'
    @migelid.name.de = 'migelid'
    @migelid.migelid_text.de = 'migelid_text'

    @migelid.add_accessory('accessory')
    @migelid.add_migelid(Migelid.new('777'))
  end
  it "code should be #{migelid_code}" do
    @migelid.code.should == migelid_code
  end
  it "migel_code should be #{group_code}.#{subgroup_code}.#{migelid_code}" do
    @migelid.migel_code.should == "#{group_code}.#{subgroup_code}.#{migelid_code}"
  end
  it "products should be empty" do
    @migelid.products.should be_empty
  end
  it "accessories[0] should be 'accessory'" do
    @migelid.accessories.first.should == 'accessory'
  end
  it "migelids[0].accessory[0] should be migelid" do
    @migelid.migelids[0].accessories[0].should == @migelid
  end
  it "parent should be a subgroup" do
    @migelid.parent.should == @subgroup
    @migelid.parent.should == @migelid.subgroup
  end
  it "limitation_text.to_s should be ''" do
    @migelid.limitation_text.should be_nil
    @migelid.limitation_text.to_s.should == ''
  end
  it "name.to_s should be 'migelid'" do
    @migelid.name.should be_an_instance_of(Migel::Util::Multilingual)
    @migelid.name.to_s.should == 'migelid'
  end
  it "name.de, en should be 'migelid'" do
    @migelid.name.de.should == 'migelid'
    @migelid.name.en.should == 'migelid'
  end
  it "name.fr should be nil" do
    @migelid.name.fr.should be_nil
  end
  it "full_description should be 'group subgroup migelid migelid_text'" do
    @migelid.full_description.should == 'group subgroup migelid migelid_text'
  end
  it "products.values should be products" do
    @migelid.products.values.should == @migelid.products
    @migelid.products.should be_empty
  end
  it "pointer should be 'pointer'" do
    @migelid.pointer.should == 'pointer'
  end
  it "localiyed_name should be @migelid" do
    @migelid.localized_name('language').should == @migelid
  end
  it "structural_ancestors should be [group, subgroup]" do
    @migelid.structural_ancestors('app').should == [@group, @subgroup]
  end
end


limitation_text = 'limitation text'
language = 'de'
describe Migelid, "when limitation_text is updated" do
  before do
    @group = Group.new(group_code)
    @subgroup = Subgroup.new(subgroup_code)
    @migelid = Migelid.new(migelid_code)
    @group.subgroups << @subgroup
    @subgroup.group = @group
    @subgroup.migelids << @migelid
    @migelid.subgroup = @subgroup
    data = {:limitation_text => limitation_text}
    #@migelid.update_limitation_text(limitation_text, language)
    @migelid.update_multilingual(data, language)
  end
  it "limitation_text.de should be '#{limitation_text}'" do
    @migelid.limitation_text.should be_an_instance_of(Migel::Util::Multilingual) 
    @migelid.limitation_text.de.should == 'limitation text'
    @migelid.limitation_text.to_s.should == 'limitation text'
    @migelid.limitation_text.en.should == 'limitation text'
  end
  it "limitation_text.fr should be nil" do
    @migelid.limitation_text.fr.should be_nil
  end
  it "limitation_text.parent should be migelid" do
    @migelid.limitation_text.parent.should == @migelid
  end
end

describe Migelid, "when name is updated" do
  before do
    @group = Group.new(group_code)
    @subgroup = Subgroup.new(subgroup_code)
    @migelid = Migelid.new(migelid_code)
    @group.subgroups << @subgroup
    @subgroup.group = @group
    @subgroup.migelids << @migelid
    @migelid.subgroup = @subgroup
 
    @migelid.name.de = 'name.de'
    @migelid.name.fr = 'name.fr'
  end
  it "name.de should be 'name.de'" do
    @migelid.name.de.should == 'name.de'
    @migelid.name.en.should == 'name.de'
    @migelid.name.fr.should == 'name.fr'
    @migelid.de.should == 'name.de'
    @migelid.en.should == 'name.de'
    @migelid.fr.should == 'name.fr'
  end
end


  end # Model
end # Migel
