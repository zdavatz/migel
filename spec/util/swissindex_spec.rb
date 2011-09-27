#! /usr/bin/env ruby
# Migel::Util::SwissindexSpec -- migel -- 07.09.2011 -- mhatakeyama@ywesee.com

$: << File.expand_path('../../lib', File.dirname(__FILE__))

require 'rspec'
require 'rspec/mocks'
require 'rspec/autorun'
require 'flexmock'
require 'drb'

include RSpec::Mocks::Methods
include FlexMock::TestCase

module Migel
  module Util
    module Swissindex

describe Swissindex, "Migel::Util::Swissindex examples" do
  before(:all) do
    @server = flexmock('swissindex_nonpharmad')
    DRbObject.stub(:new).and_return(@server)
    require 'migel/util/swissindex'
    swissindex = flexmock('swissindex', :search_migel_table => ['table'])
    @server.should_receive(:session).and_yield(swissindex)
  end
  it "search_migel_table should return an array of hash" do
    SWISSINDEX_NONPHARMA_SERVER.should be_instance_of(FlexMock)
    Migel::Util::Swissindex.search_migel_table('migel_code', 'de').should == ['table']
  end
end

    end # Swissindex
  end # Util
end # Migel
