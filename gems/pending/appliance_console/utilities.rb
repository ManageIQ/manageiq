# TODO: add appropriate requires instead of depending on appliance_console.rb.
# TODO: Further refactor these unrelated methods.
require "util/postgres_admin"
require "awesome_spawn"
require "appliance_console/logging"

module ApplianceConsole
  module Utilities
    def self.rake(task, params)
      rake_run(task, params).success?
    end

    def self.rake_run(task, params)
      result = AwesomeSpawn.run("rake #{task}", :chdir => RAILS_ROOT, :params => params)
      ApplianceConsole::Logging.logger.error(result.error) if result.failure?
      result
    end

    def self.db_connections
      result = AwesomeSpawn.run("bin/rails runner",
                                :params => ["exit EvmDatabaseOps.database_connections"],
                                :chdir  => RAILS_ROOT
                               )
      Integer(result.exit_status)
    end

    def self.bail_if_db_connections(message)
      say("Checking for connections to the database...\n\n")
      if (conns = ApplianceConsole::Utilities.db_connections - 1) > 0
        say("Warning: There are #{conns} existing connections to the database #{message}.\n\n")
        press_any_key
        raise MiqSignalError
      end
    end

    def self.db_region
      result = AwesomeSpawn.run(
        "bin/rails runner",
        :params => ["puts ApplicationRecord.my_region_number"],
        :chdir  => RAILS_ROOT
      )

      if result.failure?
        logger = ApplianceConsole::Logging.logger
        logger.error "db_region: Failed to detect region_number"
        logger.error "Output: #{result.output.inspect}" unless result.output.blank?
        logger.error "Error:  #{result.error.inspect}"  unless result.error.blank?
        return
      end

      result.output.strip
    end

    def self.pg_status
      LinuxAdmin::Service.new(PostgresAdmin.service_name).running? ? "running" : "not running"
    end

    def self.test_network
      require 'net/ping'
      say("Test Network Configuration\n\n")
      while (h = ask_for_ip_or_hostname_or_none("hostname, ip address, or none to continue").presence)
        say("  " + h + ': ' + (Net::Ping::External.new(h).ping ? 'Success!' : 'Failure, Check network settings and IP address or hostname provided.'))
      end
    end
  end
end
