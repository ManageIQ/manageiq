require_relative "evm_test_helper"

if defined?(RSpec) && defined?(RSpec::Core::RakeTask)

  require 'parallel_tests/tasks'

  namespace :test do
    namespace :vmdb do
      desc "Setup environment for vmdb specs"
      task :setup => :initialize do |rake_task|
        # in case we are called from an engine or plugin, the task might be namespaced under 'app:'
        # i.e. it's 'app:test:vmdb:setup'. Then we have to call the tasks in here under the 'app:' namespace too
        app_prefix = rake_task.name.chomp('test:vmdb:setup')
        Rake::Task["#{app_prefix}test:setup_db"].invoke
      end
    end

    desc "Run all vmdb specs"
    RSpec::Core::RakeTask.new(:vmdb => :spec_deps) do |t|
      EvmTestHelper.init_rspec_task(t)
      t.pattern = EvmTestHelper.vmdb_spec_directories
    end
  end
end # ifdef
