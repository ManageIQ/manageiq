type = ARGV.shift
require "workers/#{type}"
type.camelize.constantize.start_worker(*ARGV)
