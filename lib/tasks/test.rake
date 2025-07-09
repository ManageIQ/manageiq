require_relative 'evm_test_helper'

if defined?(RSpec)
  namespace :test do
    task :initialize do
      if ENV['RAILS_ENV'] && ENV["RAILS_ENV"] != "test"
        warn "Warning: RAILS_ENV is currently set to '#{ENV["RAILS_ENV"]}'. Forcing to 'test' for this run."
      end
      ENV['RAILS_ENV'] = "test"
      Rails.env = 'test' if defined?(Rails)

      ENV['VERBOSE'] ||= "false"
    end

    desc "Verifies that the rails environment does not require DB access"
    task :verify_no_db_access_loading_rails_environment => :initialize do
      if Rake::Task['environment'].already_invoked
        raise "Failed to verify database access when loading rails because the 'environment' rake task has already been invoked!"
      end

      EvmRakeHelper.with_dummy_database_url_configuration do
        begin
          puts "** Confirming rails environment does not connect to the database"
          Rake::Task['environment'].invoke
        rescue *ActiveRecord::Base::CONNECTIVITY_ERRORS
          STDERR.write "\e[31;1mDetected Rails environment trying to connect to the database!  Check the backtrace for an initializer trying to access the database.\n\n\e[0m"
          raise
        end
      end
    end

    desc "Verifies that a valid database is connectable"
    task :verify_connectable_with_valid_database => :initialize do
      puts "** Confirming valid database is connectable"
      Rake::Task['environment'].invoke
      raise "\e[31;1mExpected valid database to be connectable!\e[0m" unless ActiveRecord::Base.connectable?
    end

    desc "Verifies that an invalid database is not connectable"
    task :verify_not_connectable_with_invalid_database => :initialize do
      if Rake::Task['environment'].already_invoked
        raise "\e[31;1mFailed to verify database access when loading rails because the 'environment' rake task has already been invoked!\e[0m"
      end

      EvmRakeHelper.with_dummy_database_url_configuration do
        puts "** Confirming invalid database is not connectable"
        Rake::Task['environment'].invoke
        raise "\e[31;1mExpected invalid database to not be connectable!\e[0m" if ActiveRecord::Base.connectable?
      end
    end

    task :setup_db => [:initialize, :setup_region] do
      reset_task = defined?(ENGINE_ROOT) ? 'app:evm:db:reset' : 'evm:db:reset'
      Rake::Task[reset_task].invoke
    end

    task :setup_region do
      ENV["REGION"] ||= rand(1..99).to_s # Ensure we have a random, non-0, region
      puts "** Preparing database with REGION #{ENV["REGION"]}"
    end

    task :spec_deps => [:initialize, 'evm:compile_sti_loader']

    task :setup do
      test_suite = ENV["TEST_SUITE"] || "vmdb"
      Rake::Task["test:#{test_suite}:setup"].invoke
    end
  end

  task :default => :test

  task :test do
    test_suite = ENV["TEST_SUITE"] || "vmdb"
    Rake::Task["test:#{test_suite}"].invoke
  end
end # ifdef
