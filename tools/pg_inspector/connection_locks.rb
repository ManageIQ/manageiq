require 'optimist'
require 'yaml'
require 'pg_inspector/error'
require 'pg_inspector/pg_inspector_operation'
require 'pg_inspector/util'

module PgInspector
  class LockConnectionYAML < PgInspectorOperation
    HELP_MSG_SHORT = "Dump lock friendly connection information to YAML file".freeze
    attr_accessor :locks, :connections, :blocked_connections

    def parse_options(args)
      self.options = Optimist.options(args) do
        opt(:locks, "Lock file",
            :type => :string, :short => "l", :default => DEFAULT_OUTPUT_PATH.join("#{PREFIX}locks.yml").to_s)
        opt(:connections, "Human readable active connections file",
            :type => :string, :short => "c", :default => DEFAULT_OUTPUT_PATH.join("#{PREFIX}human.yml").to_s)
        opt(:output, "Output file",
            :type => :string, :short => "o", :default => DEFAULT_OUTPUT_PATH.join("#{PREFIX}locks_output.yml").to_s)
        opt(:output_blocked, "Output blocked connections file",
            :type => :string, :short => "b", :default => DEFAULT_OUTPUT_PATH.join("#{PREFIX}locks_output_blocked_connections.yml").to_s)
      end
    end

    def run
      load_connection_file
      load_lock_file
      process_lock_file
      Util.dump_to_yml_file(
        merge_lock_and_connection,
        "Lock friendly connection info",
        options[:output]
      )
      unless blocked_connections.empty?
        Util.dump_to_yml_file(
          blocked_connections,
          "Blocked connections",
          options[:output_blocked]
        )
      end
    end

    private

    def merge_lock_and_connection
      some_connection_blocked = false
      self.blocked_connections = []
      connections["connections"].each do |conn|
        conn["blocked_by"] = find_lock_blocking_spid(conn["spid"])
        unless conn["blocked_by"].empty?
          some_connection_blocked = true
          puts "Connection #{conn["spid"]} is blocked by #{conn["blocked_by"]}."
          blocked_connections << {conn["spid"] => conn["blocked_by"]}
        end
      end
      unless some_connection_blocked
        puts "Every connection is OK and not blocked. No need to generate lock graph."
      end
      connections
    end

    def load_connection_file
      self.connections = YAML.load_file(options[:connections])
    rescue => e
      Util.error_exit(e)
    end

    def load_lock_file
      self.locks = YAML.load_file(options[:locks])
    rescue => e
      Util.error_exit(e)
    end

    def process_lock_file
      locks.each do |lock|
        lock["spid"] = lock["pid"].to_i
        lock.delete("pid")
      end
      locks.each do |lock|
        lock["blocked_by"] = connection_spids_blocking_lock(lock)
      end
    end

    def connection_spids_blocking_lock(lock)
      return if lock["granted"] == "t"
      blocking_locks = blocking_lock_relation(lock).select do |l|
        lock["spid"] != l["spid"] &&
          l["granted"] == "t"
      end
      blocking_locks.collect { |l| l["spid"] }.uniq
    end

    def blocking_lock_relation(lock)
      case lock["locktype"]
      when "relation"
        select_lock(lock, "relation", "database")
      when "virtualxid"
        select_lock(lock, "virtualxid")
      when "transactionid"
        select_lock(lock, "transationid")
      when "tuple"
        select_lock(lock, "database", "relation", "page", "tuple")
      else
        $stderr.puts("Warning: unexpected lock type #{lock["locktype"]} encountered.")
      end
    end

    def select_lock(lock, *args)
      locks.select { |l| args.all? { |field| l[field] == lock[field] } }
    end

    def locks_owned_by_spid(spid)
      locks.select { |l| l["spid"] == spid }
    end

    def find_lock_blocking_spid(spid)
      locks_owned_by_spid(spid).collect { |lock| lock["blocked_by"] }.compact.flatten.uniq
    end
  end
end
