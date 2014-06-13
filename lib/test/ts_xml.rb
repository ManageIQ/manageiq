require_relative './test_helper'

$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/xml")
$:.push("#{File.dirname(__FILE__)}/../util")
require 'miq-logger'

# Setup console logging
$log = MIQLogger.get_log(nil, nil)
$log.level = Log4r::WARN

require 'tc_xml'
require 'tc_rexml'
require 'tc_nokogiri'
require 'tc_xmlhash_methods.rb'
require 'tc_encoding.rb'
