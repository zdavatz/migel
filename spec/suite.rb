#!/usr/bin/env ruby
# suite.rb -- migel -- 07.09.2011 -- mhatakeyama@ywesee.com 

require 'find'

here = File.dirname(__FILE__)
require 'simplecov'; 
SimpleCov.start;

$: << here

Find.find(here) { |file|
	if /.*_spec\.rb$/o.match(file)
    require file
	end
}
