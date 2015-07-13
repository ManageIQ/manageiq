module VmdbDatabase::MetricCollection
  extend ActiveSupport::Concern

  module ClassMethods
    def collect_database_metrics_sql
      { :active_connections => collect_number_connections }
    end

    def collect_database_metrics_os(data_directory = nil)
      metrics = { :running_processes => collect_number_pg_processes }

      unless data_directory.nil?
        du = MiqSystem.disk_usage(data_directory).first
        metrics[:disk_total_bytes]  = du[:total_bytes]
        metrics[:disk_used_bytes]   = du[:used_bytes]
        metrics[:disk_free_bytes]   = du[:available_bytes]
        metrics[:disk_total_inodes] = du[:total_inodes]
        metrics[:disk_used_inodes]  = du[:used_inodes]
        metrics[:disk_free_inodes]  = du[:available_inodes]
      end

      metrics
    end

    def collect_number_pg_processes
      require 'miq-process'
      (MiqProcess.get_active_process_by_name('postmaster') + MiqProcess.get_active_process_by_name('postgres')).uniq.length
    end

    def collect_number_connections
      active_connections = 0
      active_connections = connection.number_of_db_connections if connection.respond_to?(:number_of_db_connections)
      active_connections
    end

  end
end
