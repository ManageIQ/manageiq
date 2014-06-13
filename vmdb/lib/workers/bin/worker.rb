#!/usr/bin/env ruby script/runner

type = ARGV.shift
require "workers/#{type}"
type.camelize.constantize.start_worker(*ARGV)
