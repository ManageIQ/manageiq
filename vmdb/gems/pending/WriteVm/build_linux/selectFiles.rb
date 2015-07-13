require 'find'
require 'fileutils'
require 'yaml'
require 'ostruct'

require '../../../../build_tools/MiqCollectFiles'

cf = MiqCollectFiles.new(ARGV[0])
cf.verbose = true
cf.collect
