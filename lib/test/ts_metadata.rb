require_relative './test_helper'

$:.push("#{File.dirname(__FILE__)}")
require 'extract/tc_versioninfo.rb'

$:.push("#{File.dirname(__FILE__)}/../metadata")
require 'MIQExtract/test/full_extract_test.rb'
