require_relative './test_helper'

require 'util/miq-logger'

# Setup console logging
$log = MIQLogger.get_log(nil, nil)
$log.level = Log4r::WARN

require_relative 'extract/tc_versioninfo.rb'
require_relative 'extract/tc_md5deep.rb'
require_relative 'extract/tc_registry.rb'
