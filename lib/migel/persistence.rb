#!/usr/bin/env ruby
# enconding: utf-8
# Migel@persistence -- migel -- 17.08.2011 -- mhatakeyama@ywesee.com

require 'migel/config'

module Migel 
  require File.join('migel', 'persistence', @config.persistence)
  persistence = nil
  DRb.install_id_conv ODBA::DRbIdConv.new
  @persistence = Migel::Persistence::ODBA
end
