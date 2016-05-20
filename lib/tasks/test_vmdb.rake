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

  desc "Run all vmdb specs; Use PARALLEL=1 to run in parallel."
  task :vmdb do
    if ENV['PARALLEL']
      Rake::Task['vmdb_parallel'].invoke
    else
      Rake::Task['vmdb_sequential'].invoke
    end
  end

  # Private
  task :vmdb_sequential do
    # Create an anonymous rake task and invoke to avoid RSpec adding a rake description
    RSpec::Core::RakeTask.new(:nop => [:initialize, "evm:compile_sti_loader"]) do |t|
      EvmTestHelper.init_rspec_task(t)
      t.pattern = EvmTestHelper.vmdb_spec_directories
    end.invoke
  end

  # Private
  task :vmdb_parallel => [:initialize, "evm:compile_sti_loader"] do
    ParallelTests::CLI.new.run(["--type", "rspec"] + EvmTestHelper.vmdb_spec_directories)
  end
end
end # ifdef
