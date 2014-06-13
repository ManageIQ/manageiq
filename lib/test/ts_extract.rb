require_relative './test_helper'

$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../util")
require 'miq-logger'

# Setup console logging
$log = MIQLogger.get_log(nil, nil)
$log.level = Log4r::WARN

require 'extract/tc_versioninfo.rb'
require 'extract/tc_md5deep.rb'
require 'extract/tc_registry.rb'
