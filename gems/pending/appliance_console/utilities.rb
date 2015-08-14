#TODO: add appropriate requires instead of depending on appliance_console.rb.
#TODO: Further refactor these unrelated methods.
require "appliance_console/internal_database_configuration"

module ApplianceConsole
  module Utilities
    def self.db_connections
      require 'open4'
      status = Open4::popen4("cd #{RAILS_ROOT} && script/rails runner 'exit EvmDatabaseOps.database_connections'") { |pid,  stdin, stdout, stderr| }
      Integer(status.exitstatus)
    end

    def self.bail_if_db_connections(message)
      say("Checking for connections to the database...\n\n")
      if (conns = ApplianceConsole::Utilities.db_connections - 1) > 0
        say("Warning: There are #{conns} existing connections to the database #{message}.\n\n")
        press_any_key
        raise MiqSignalError
      end
    end

    def self.db_host_type_database
      require 'open4'
      out = nil
      err = nil
      Open4::popen4("cd #{RAILS_ROOT} && script/rails runner 'puts MiqDbConfig.current.options[:host]|| \"localhost\"; puts MiqDbConfig.current.options[:name]; puts MiqDbConfig.current.options[:database]'") do |pid, stdin, stdout, stderr|
        out = stdout.read
        err = stderr.read
      end
      out = out.chomp.split("\n")
      host, type, database = out[-3..-1]
      unless [host, type, database].all? { |res| res.kind_of?(String) }
        File.open(LOGFILE, 'a') do |f|
          f.puts "db_host_type_database: Failed to detect some/all DB configuration"
          f.puts "Output: #{out.inspect}" if out.to_s.length > 0
          f.puts "Error:  #{err.inspect}" if err.to_s.length > 0
        end
      end
      host = host.to_s
      type = type.to_s
      database = database.to_s
      type = "postgresql" if type.strip =~ /^(in|ex)ternal/
      return host, type, database
    end

    def self.pg_status
      system("service #{InternalDatabaseConfiguration.postgresql_service} status > /dev/null 2>&1")
      return $?.exitstatus == 0 ? "running" : "not running"
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
