type = ARGV.shift
require "workers/#{type.underscore}" unless type.include?("::")
type.constantize.start_worker(*ARGV)
