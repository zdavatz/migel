#!/usr/bin/env ruby
# Migel -- migel -- 17.08.2011 -- mhatakeyama@ywesee.com


module Migel
  VERSION = '1.0.0'
#  Migel_VERSION =
#    File.read(File.expand_path('../.git/refs/heads/master',
#                               File.dirname(__FILE__)))
  class << self
    attr_accessor :config, :logger, :persistence, :server
  end
end
