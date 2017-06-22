require_relative "./evm_test_helper"

if defined?(RSpec) && defined?(RSpec::Core::RakeTask)
namespace :test do
  namespace :vmdb do
    desc "Setup environment for vmdb specs"
    task :setup => [:initialize, :verify_no_db_access_loading_rails_environment] do
      if ENV['PARALLEL']
        database_config = Pathname.new(__dir__).expand_path + "../../config/database.yml"
        if File.readlines(database_config).grep(/TEST_ENV_NUMBER/).size > 0
          require 'parallel_tests'
          ParallelTests::CLI.new.run(["--type", "rspec"] + ["-e", "bin/rake evm:db:reset"])
        else
          puts "Oops! Your database.yml doesn't appear to support parallel tests!"
          puts "Update your config/database.yml with TEST_ENV_NUMBER as seen in the example (database.pg.yml), then try again."
          exit(1)
        end
      else
        Rake::Task['test:setup_db'].invoke
      end
    end
  end

  desc "Run all vmdb specs; Use PARALLEL=true to run in parallel."
  task :vmdb do
    if ENV['PARALLEL']
      Rake::Task['test:vmdb_parallel'].invoke
    else
      Rake::Task['test:vmdb_sequential'].invoke
    end
  end

  # TODO: Send a patch upstream to avoid adding a Rake task description; remove the parallel one too
  RSpec::Core::RakeTask.new(:vmdb_sequential => [:initialize, "evm:compile_sti_loader"]) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = EvmTestHelper.vmdb_spec_directories
  end

  desc "Run RSpec code examples in parallel"
  task :vmdb_parallel => [:initialize, "evm:compile_sti_loader"] do
    # Check that '<name_of_test_database>2' exists, else you need additional setup
    test_config = Rails.configuration.database_configuration['test'].tap { |config| config['database'].concat('2') }
    begin
      ActiveRecord::Base.establish_connection(test_config)
      ActiveRecord::Base.retrieve_connection
    rescue ActiveRecord::NoDatabaseError
      puts "Oops! Your test databases don't appear to be set up properly for running tests in parallel."
      puts "Run 'PARALLEL=true bin/rake test:vmdb:setup', then try again."
      exit(1)
    ensure
      ActiveRecord::Base.remove_connection
    end

    require 'parallel_tests'
    ParallelTests::CLI.new.run(["--type", "rspec"] + EvmTestHelper.vmdb_spec_directories)
  end
end
end # ifdef
