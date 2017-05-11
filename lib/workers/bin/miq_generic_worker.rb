ENV['BUNDLER_GROUPS'] = ""

require File.expand_path('../../../config/application', __dir__)

Vmdb::Application.initialize!
MiqGenericWorker::Runner.start_worker(*ARGV)
