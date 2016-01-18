#!/usr/bin/env ruby
# encoding: utf-8
# Migel -- migel -- 17.08.2011 -- mhatakeyama@ywesee.com


module Migel
  VERSION = '1.0.1'
  class << self
    attr_accessor :config, :logger, :persistence, :server
  end
end
