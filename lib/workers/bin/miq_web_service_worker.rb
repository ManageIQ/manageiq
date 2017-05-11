ENV['BUNDLER_GROUPS'] = "web_server,rest_api"

require File.expand_path('../../../config/application', __dir__)

Vmdb::Application.initialize!
MiqWebServiceWorker.preload_for_worker_role
MiqWebServiceWorker::Runner.start_worker(*ARGV)
