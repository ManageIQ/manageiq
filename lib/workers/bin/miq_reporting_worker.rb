ENV['BUNDLER_GROUPS'] = ""

require File.expand_path('../../../config/application', __dir__)

Vmdb::Application.initialize!
MiqReportingWorker::Runner.start_worker(*ARGV)
