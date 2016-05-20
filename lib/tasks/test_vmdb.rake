require 'parallel_tests'
require_relative "./evm_test_helper"

if defined?(RSpec) && defined?(RSpec::Core::RakeTask)
namespace :test do
  namespace :vmdb do
    desc "Setup environment for vmdb specs"
    task :setup => [:initialize, :verify_no_db_access_loading_rails_environment] do
      ParallelTests::CLI.new.run(["--type", "rspec"] + ["-e", "bin/rake evm:db:reset"])
    end

    task :teardown
  end

  desc "Run all core specs (excludes automation, migrations, replication, etc)"
  RSpec::Core::RakeTask.new(:vmdb => [:initialize, "evm:compile_sti_loader"]) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = EvmTestHelper.vmdb_spec_directories
  end

  desc "Run all core specs in parallel"
  task :vmdb_parallel => [:initialize, :verify_no_db_access_loading_rails_environment] do
    ParallelTests::CLI.new.run(["--type", "rspec"] + EvmTestHelper.vmdb_spec_directories)
  end
end
end # ifdef
