require 'trollop'
require 'pg'
require 'activerecord-id_regions'
require 'pg_inspector/error'
require 'pg_inspector/pg_inspector_operation'
require 'pg_inspector/util'

module PgInspector
  class ActiveConnectionsHumanYAML < PgInspectorOperation
    HELP_MSG_SHORT = "DUMP active connections to human readable YAML file".freeze
    def parse_options(args)
      self.options = Trollop.options(args) do
        opt(:connections, "Active connections file",
            :type => :string, :short => "c", :default => "active_connections.yml")
        opt(:servers, "Servers information file",
            :type => :string, :short => "s", :default => "server.yml")
        opt(:output, "Output file",
            :type => :string, :short => "o", :default => "human.yml")
      end
    end

    def run
      Util.dump_to_yml_file(
        merge_activity_and_server_info(
          process_stat_activity_file(options[:connections]),
          process_miq_info_file(options[:servers])
        ), "Human readable active connections", options[:output]
      )
    end

    private

    def process_stat_activity_file(file_name)
      stat_activities = YAML.load_file(file_name)
      result = {
        "servers"         => [],
        "workers"         => [],
        "other_processes" => []
      }
      stat_activities.each do |activity|
        if server_activity?(activity)
          result["servers"] << process_miq_activity(activity)
        elsif worker_activity?(activity)
          result["workers"] << process_miq_activity(activity)
        else
          result["other_processes"] << activity
        end
      end
      result
    rescue => e
      Util.error_exit(e)
    end

    def server_activity?(activity)
      miq_activity?(activity) && activity["application_name"].split("|")[3] == "-"
    end

    def worker_activity?(activity)
      miq_activity?(activity) && activity["application_name"].split("|")[3] != "-"
    end

    def miq_activity?(activity)
      activity["application_name"].start_with?("MIQ")
    end

    def process_miq_activity(activity)
      activity["datid"] = activity["datid"].to_i
      activity["pid"] = activity["pid"].to_i
      activity["usesysid"] = activity["usesysid"].to_i
      process_miq_activity_application_name(activity)
    end

    def process_miq_activity_application_name(activity)
      # Current :application_name format:
      # MIQ|<pid>|<server_id>|<worker_id>|<zone_id>|<class_name>|<zone_name>
      if activity["application_name"].end_with?("...")
        $stderr.puts("Warning: the application_name #{activity["application_name"]} is incomplete.")
      end
      _, pid, server_id, worker_id, zone_id, class_name, zone_name = activity["application_name"].split("|")
      activity["spid"] = pid.to_i
      activity["class_name"] = class_name
      activity["server_compressed_id"] = server_id
      activity["worker_compressed_id"] = worker_id if worker_id != "-"
      activity["zone_compressed_id"] = zone_id
      activity["zone_name"] = zone_name
      activity
    end

    def process_miq_info_file(file_name)
      servers = YAML.load_file(file_name)
      result = []
      servers.each { |server| result << process_miq_server(server) }
      result
    rescue => e
      Util.error_exit(e)
    end

    def process_miq_server(server)
      server["server_compressed_id"] = compress_id(server["id"])
      server.select { |k, _v| %w(server_compressed_id hostname ipaddress).include?(k) }
    end

    def compress_id(id)
      Class.new.include(ActiveRecord::IdRegions).compress_id(id)
    end

    def merge_activity_and_server_info(stat_activities, servers)
      server_activities = array_of_hash_to_hash(stat_activities["servers"], "server_compressed_id")
      servers.each do |server|
        server_activities[server["server_compressed_id"]] = server_activities[server["server_compressed_id"]].merge(server)
      end
      stat_activities["servers"] = hash_val_array(server_activities)
      stat_activities
    end

    def array_of_hash_to_hash(array, key)
      result = {}
      array.each do |e|
        result[e[key]] = e
      end
      result
    end

    def hash_val_array(hash)
      result = []
      hash.each do |_k, v|
        result << v
      end
      result
    end
  end
end
