$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../../util")
require 'test/unit'
require 'miq-logger'

# Setup console logging
$log = MIQLogger.get_log(nil, nil)
$log.level = Log4r::DEBUG

require 'tc_inventory'
require 'tc_modify'
require 'tc_powerstates'
require 'tc_snapshot'
