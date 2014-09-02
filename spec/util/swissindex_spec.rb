#! /usr/bin/env ruby
# ODDB::SwissindexSpec -- migel -- 07.09.2011 -- mhatakeyama@ywesee.com

$: << File.expand_path('../../lib', File.dirname(__FILE__))

require 'rspec'
require 'rspec/mocks'
require 'rspec/autorun'
require 'flexmock'
require 'drb'

#include RSpec::Mocks::Methods
include FlexMock::TestCase

module Migel
  module Util
    module Swissindex

describe Swissindex, "ODDB::Swissindex examples" do
  before(:all) do
    @server = flexmock('swissindex_nonpharmad')
    DRbObject.stub(:new).and_return(@server)
    require 'migel/ext/swissindex'
    swissindex = flexmock('swissindex', :search_migel_table => ['table'])
    @server.should_receive(:session).and_yield(swissindex)
  end
  it "search_migel_table should return an array of hash" do
    SWISSINDEX_NONPHARMA_URI    = 'druby://localhost:50002'
    pending("Don't know how to make it pass")
    Migel::SwissindexNonpharmaPlugin::SWISSINDEX_NONPHARMA_SERVER.should be_instance_of(FlexMock)
    ODDB::Swissindex.search_migel_table('migel_code', 'de').should == ['table']
  end
end

    end # Swissindex
  end # Util
end # Migel
