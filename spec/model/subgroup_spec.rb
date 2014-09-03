#! /usr/bin/env ruby
# Migel::Model::SubgroupSpec -- migel -- 09.09.2011 -- mhatakeyama@ywesee.com

$: << File.expand_path('../../lib', File.dirname(__FILE__))

require 'rspec'
require 'rspec/autorun'
require 'migel/model_super'
require 'migel/model/group'
require 'migel/model/subgroup'
require 'migel/util/multilingual'
require 'odba/drbwrapper'

module Migel
  module Model

    group_code    = 11
    subgroup_code = 22
describe Subgroup, "when initialized with code #{subgroup_code} (group_code: #{group_code})" do
  before do
    @group = Group.new(group_code)
    @subgroup = Subgroup.new(subgroup_code)
    @group.subgroups << @subgroup
    @subgroup.group = @group
  end
  it "code should be #{subgroup_code}" do
    @subgroup.code.should == subgroup_code
  end
  it "migel_code should be #{group_code}.#{subgroup_code}" do
    @subgroup.migel_code.should == "#{group_code}.#{subgroup_code}"
  end
  it "migelids should be empty" do
    @subgroup.migelids.should be_empty
  end
  it "parent should be group" do
    @subgroup.parent.should == @group
    @subgroup.parent.should == @subgroup.group
  end
  it "limitation_text.to_s should be ''" do
    @subgroup.limitation_text.should be_nil
    @subgroup.limitation_text.to_s.should == ''
  end
  it "name.to_s should be ''" do
    @subgroup.name.should be_an_instance_of(Migel::Util::Multilingual)
    @subgroup.name.to_s.should == ''
  end
  it "name.xx should be nil" do
    @subgroup.name.de.should be_nil
    @subgroup.name.fr.should be_nil
    @subgroup.name.en.should be_nil
  end
  it "structural_ancestors should be [group]" do
    @subgroup.structural_ancestors('app').should == [@group]
  end
  it "pointer should be 'pointer'" do
    @subgroup.pointer.should == 'pointer'
  end
  it "items should be nil" do
    @subgroup.items.should be_nil
  end
  it "product_text should be nil" do
    @subgroup.product_text.should be_nil
  end
  it "respond_to? should have two arguments" do
    @subgroup.respond_to?(:name, 'hogehoge').should be true
  end
end

    limitation_text = 'limitation text'
    language = 'de'
describe Subgroup, "when limitation_text is updated" do
  before do

    @group = Group.new(group_code)
    @subgroup = Subgroup.new(subgroup_code)
    @group.subgroups << @subgroup
    @subgroup.group = @group
    @subgroup.update_limitation_text(limitation_text, language)
  end
  it "limitation_text.de should be '#{limitation_text}'" do
    @subgroup.limitation_text.should be_an_instance_of(Migel::Util::Multilingual) 
    @subgroup.limitation_text.de.should == 'limitation text'
    @subgroup.limitation_text.to_s.should == 'limitation text'
    @subgroup.limitation_text.en.should == 'limitation text'
    @subgroup.limitation_text.fr.should be_nil
  end
end

describe Subgroup, "when name is updated" do
  before do
    @group = Group.new(group_code)
    @subgroup = Subgroup.new(subgroup_code)
    @group.subgroups << @subgroup
    @subgroup.group = @group
 
    @subgroup.name.de = 'name.de'
    @subgroup.name.fr = 'name.fr'
  end
  it "name.de should be 'name.de'" do
    @subgroup.name.de.should == 'name.de'
    @subgroup.name.en.should == 'name.de'
    @subgroup.name.fr.should == 'name.fr'
    @subgroup.de.should == 'name.de'
    @subgroup.en.should == 'name.de'
    @subgroup.fr.should == 'name.fr'
  end
end


  end # Model
end # Migel
