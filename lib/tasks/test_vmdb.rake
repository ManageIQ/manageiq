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
    t.pattern = EvmTestHelper::VMDB_SPECS
  end

  desc "Run all core specs in parallel"
  task :vmdb_parallel => [:initialize, :verify_no_db_access_loading_rails_environment] do
    def vmdb_directories_for_parallel
      # TODO: Clean up this thing
      # Within the spec directory, find:
      #  * directories
      #  * that aren't automation/migrations/replication (the excluded directories)
      #  * that contain *_spec.rb files
      #
      # Output: %w(./spec/controllers ./spec/helpers ./spec/initializers ..)
      Dir.glob("./spec/*").select do |d|
        File.directory?(d) &&
          !EvmTestHelper::VMDB_EXCLUDED_SPEC_DIRECTORIES.include?(File.basename(d)) &&
          !Dir.glob("#{d}/**/*_spec.rb").empty?
      end
    end
  end
end
end # ifdef
