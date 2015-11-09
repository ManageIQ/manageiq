require_relative './evm_test_helper'

if defined?(RSpec)
namespace :test do
  task :initialize do
    ENV['RAILS_ENV'] ||= "test"
    Rails.env = ENV['RAILS_ENV'] if defined?(Rails)
    ENV['VERBOSE']   ||= "false"
  end

  task :verify_no_db_access_loading_rails_environment do
    EvmRakeHelper.with_dummy_database_url_configuration do
      begin
        puts "** Confirming rails environment does not connect to the database"
        Rake::Task['environment'].invoke
      rescue ActiveRecord::NoDatabaseError
        STDERR.write "Detected Rails environment trying to connect to the database!  Check the backtrace for an initializer trying to access the database.\n\n"
        raise
      end
    end
  end

  task :setup_db => :initialize do
    puts "** Preparing database"
    Rake::Task['evm:db:reset'].invoke
  end
end

task :default => 'test:vmdb'
end # ifdef
