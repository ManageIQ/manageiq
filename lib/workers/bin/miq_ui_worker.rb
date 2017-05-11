ENV['BUNDLER_GROUPS'] = "web_server,ui_dependencies"

require File.expand_path('../../../config/application', __dir__)

Vmdb::Application.initialize!
MiqUiWorker.preload_for_worker_role
MiqUiWorker::Runner.start_worker(*ARGV)
