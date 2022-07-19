require 'awesome_spawn'
require 'evm_rake_helper'

namespace :evm do
  namespace :db do
    desc 'Start the local ManageIQ EVM Database (VMDB)'
    task :start do
      LinuxAdmin::Service.new(ENV.fetch("APPLIANCE_PG_SERVICE")).start
    end

    desc 'Stop the local ManageIQ EVM Database (VMDB)'
    task :stop do
      LinuxAdmin::Service.new(ENV.fetch("APPLIANCE_PG_SERVICE")).stop
    end

    # Start the EVM Database silently - not to be a visible rake task
    task :silent_start do
      begin
        LinuxAdmin::Service.new(ENV.fetch("APPLIANCE_PG_SERVICE")).start
      rescue AwesomeSpawn::CommandResultError
        # ignore issues (ala silent)
      end
    end

    # Stop the EVM Database silently - not to be a visible rake task
    task :silent_stop do
      begin
        LinuxAdmin::Service.new(ENV.fetch("APPLIANCE_PG_SERVICE")).stop
      rescue AwesomeSpawn::CommandResultError
        # ignore issues (ala silent)
      end
    end

    desc "Seed the ManageIQ EVM Database (VMDB) with defaults"
    task :seed do
      Rake::Task['db:seed'].invoke
    end

    desc "Destroys the ManageIQ EVM Database (VMDB) of all tables, views and indices"
    task :destroy do
      begin
        Rake::Task['environment'].invoke
      rescue => err
        # Allow "destroying" a database that doesn't exist
        raise unless err.message =~ /does not exist$/
      end

      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke

      # db:create creates a temporary connection to the default database, but doesn't
      # remove the connection in the event of a failed create, so we drop the connection
      # and reestablish it to the environment's database.
      ActiveRecord::Base.remove_connection
      ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[Rails.env])
    end

    desc "Resets the ManageIQ EVM Database (VMDB) of all tables, views and indices"
    task :reset => [:destroy, 'db:migrate']

    # schema.rb doesn't support views which is used by metrics
    task :db_setup_not_supported do
      warn "db:setup and db:reset are not supported! Please use evm:db:reset, db:migrate, or test:vmdb:setup instead."
      exit 1
    end

    # this is used by the appliance console to create a db
    # Example usage:
    #   RAILS_ENV=production REGION=99 bin/rake evm:db:region
    # Alt usage:
    #   RAILS_ENV=production REGION=99 VERBOSE=false bin/rake db:reset db:seed

    desc 'Set the region of the current ManageIQ EVM Database (VMDB)'
    task :region => "evm:db:reset" do
      region = ENV["REGION"]

      puts "Initializing region and database..."
      AwesomeSpawn.run!("bin/rails runner", :params => ["MiqDatabase.seed; MiqRegion.seed"])
    rescue => err
      message = err.kind_of?(AwesomeSpawn::CommandResultError) ? err.result.error : err.message
      STDERR.puts "Encountered issue setting up Database using region #{region}: #{message}\n"
      raise
    end
  end
end

Rake::Task["db:setup"].prerequisites.unshift("evm:db:db_setup_not_supported")
Rake::Task["db:reset"].prerequisites.unshift("evm:db:db_setup_not_supported")
