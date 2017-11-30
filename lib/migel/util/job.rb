#! /usr/bin/env ruby
# encoding: utf-8
# Migel::Util::Job -- migel -- 06.01.2012 -- mhatakeyama@ywesee.com

require 'drb'
require 'migel/config'
require 'migel/util/server'
require 'migel/model'
require 'migel/persistence/odba'

module Migel
  module Util
module Job
  def Job.run opts={}, &block
    system = DRb::DRbObject.new(nil, Migel.config.server_url)
    DRb.start_service
    begin
      ODBA.cache.setup
      ODBA.cache.clean_prefetched
      DRb.install_id_conv ODBA::DRbIdConv.new
      system.peer_cache ODBA.cache unless opts[:readonly] rescue Errno::ECONNREFUSED
      block.call Migel::Util::Server.new
    ensure
      system.unpeer_cache ODBA.cache unless opts[:readonly]
    end
  end
end
  end
end
