#! /usr/bin/env ruby
# Migel::Model::GroupSpec -- migel -- 13.09.2011 -- mhatakeyama@ywesee.com

$: << File.expand_path('../../lib', File.dirname(__FILE__))

require 'rspec'
require 'migel/model_super'
require 'migel/model/group'
require 'migel/util/multilingual'
require 'odba/drbwrapper'
require 'rspec/autorun' # Required for Rcov to run.

module Migel
  module Model

describe Group, "when initialized with migel code 15" do
  before do
    group_code = '15'
    @group = Group.new(group_code)
  end
  it "migel code should be 15" do
    @group.code.should == '15'
    @group.migel_code.should == '15'
    @group.pointer_descr.should == '15'
  end
  it "subgroups should be empty" do
    @group.subgroups.should be_empty
  end
  it "limitation_text.to_s should be ''" do
    @group.limitation_text.should be_nil
    @group.limitation_text.to_s.should == ''
  end
  it "name.to_s should be ''" do
    @group.name.should be_an_instance_of(Migel::Util::Multilingual)
    @group.name.to_s.should == ''
  end
  it "name.xx should be nil" do
    @group.name.de.should be_nil
    @group.name.fr.should be_nil
    @group.name.en.should be_nil
  end
  it "parent should be nil" do
    @group.parent.should be_nil
  end
  it "pointer should be 'pointer'" do
    @group.pointer.should == 'pointer'
  end
end

describe Group, "when limitation_text is updated" do
  before do
    migel_code = '15'
    limitation_text = 'limitation text'
    language = 'de'
    @group = Group.new(migel_code)
    @group.update_limitation_text(limitation_text, language)
  end
  it "limitation_text.de should be 'limitation text'" do
    @group.limitation_text.should be_an_instance_of(Migel::Util::Multilingual) 
    @group.limitation_text.de.should == 'limitation text'
    @group.limitation_text.to_s.should == 'limitation text'
    @group.limitation_text.en.should == 'limitation text'
    @group.limitation_text.fr.should be_nil
  end
end

describe Group, "when name is updated" do
  before do
    migel_code = '15'
    @group = Group.new(migel_code)
    @group.name.de = 'name.de'
    @group.name.fr = 'name.fr'
  end
  it "name.de should be 'name.de'" do
    @group.name.de.should == 'name.de'
    @group.name.en.should == 'name.de'
    @group.name.fr.should == 'name.fr'
    @group.de.should == 'name.de'
    @group.en.should == 'name.de'
    @group.fr.should == 'name.fr'
  end
end

  end # Model
end # Migel
