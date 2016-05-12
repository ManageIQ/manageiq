require_relative "./evm_test_helper"

if defined?(RSpec) && defined?(RSpec::Core::RakeTask)
  namespace :test do
    namespace :websocket do
      desc "Setup environment for websocket specs"
      task :setup => :setup_db

      task :teardown
    end

    desc "Run all websocket specs"
    RSpec::Core::RakeTask.new(:websocket => [:initialize]) do |t|
      EvmTestHelper.init_rspec_task(t)
      t.pattern = EvmTestHelper::WEBSOCKET_SPECS
    end
  end
end # ifdef
