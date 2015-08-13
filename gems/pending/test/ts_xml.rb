require_relative './test_helper'

require 'util/miq-logger'

# Setup console logging
$log = MIQLogger.get_log(nil, nil)
$log.level = Log4r::WARN

require_relative 'xml/tc_xml'
require_relative 'xml/tc_rexml'
require_relative 'xml/tc_nokogiri'
require_relative 'xml/tc_xmlhash_methods.rb'
require_relative 'xml/tc_encoding.rb'
