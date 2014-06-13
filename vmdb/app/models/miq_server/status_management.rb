require 'miq-system'

module MiqServer::StatusManagement
  extend ActiveSupport::Concern

  module ClassMethods
    def status_update
      require 'miq-process'
      pinfo = MiqProcess.processInfo
      # Ensure the hash only contains the values we want to store in the table
      pinfo.delete_if {|k,v| ![:priority, :memory_usage, :percent_memory, :percent_cpu, :memory_size, :cpu_time].include?(k)}
      pinfo[:os_priority] = pinfo.delete(:priority)
      self.my_server.update_attributes(pinfo)
    end

    def log_status
      log_prefix = "MIQ(MiqServer.log_status)"
      self.log_system_status
      svr = self.my_server(true)
      $log.info("#{log_prefix} [#{svr.friendly_name}] Process info: Memory Usage [#{svr.memory_usage}], Memory Size [#{svr.memory_size}], Memory % [#{svr.percent_memory}], CPU Time [#{svr.cpu_time}], CPU % [#{svr.percent_cpu}], Priority [#{svr.os_priority}]") unless svr.nil?
    end

    def log_system_status
      log_prefix = "MIQ(MiqServer.log_system_status)"
      svr        = self.my_server
      svr_name   = svr ? svr.friendly_name : "EVM Server (Unidentified)"

      status = MiqSystem.memory
      unless status.empty?
        $log.info("#{log_prefix} [#{svr_name}] System Status:")
        status.keys.sort_by { |k| k.to_s }.each { |k| $log.info("#{log_prefix} [#{svr_name}]     #{k}: #{status[k]}") }
      end

      disks = MiqSystem.disk_usage
      unless disks.empty?
        $log.info("#{log_prefix} [#{svr_name}] Disk Usage:")
        format_string = "%-12s %6s %12s %12s %12s %12s %12s %12s %12s %12s %12s"
        header = format(format_string,
          "Filesystem",
          "Type",
          "Total",
          "Used",
          "Available",
          "%Used",
          "iTotal",
          "iUsed",
          "iFree",
          "%iUsed",
          "Mounted on"
        )
        $log.info("#{log_prefix} [#{svr_name}] #{header}")

        disks.each do |disk|
          formatted = format(format_string,
            disk[:filesystem],
            disk[:type],
            ActionView::Base.new.number_to_human_size(disk[:total_bytes]),
            ActionView::Base.new.number_to_human_size(disk[:used_bytes]),
            ActionView::Base.new.number_to_human_size(disk[:available_bytes]),
            "#{disk[:used_bytes_percent]}%",
            disk[:total_inodes],
            disk[:used_inodes],
            disk[:available_inodes],
            "#{disk[:used_inodes_percent]}%",
            disk[:mount_point]
          )
          $log.info("#{log_prefix} [#{svr_name}] #{formatted}")
        end

        # Raise events if disk usage above threshold
        svr.check_disk_usage(disks)
      end

      queue_count = MiqQueue.nested_count_by(%w(state zone role))
      states = queue_count.keys.sort_by { |k| k.to_s }
      states.each { |state| $log.info("#{log_prefix} [#{svr_name}] MiqQueue count for state=[#{state.inspect}] by zone and role: #{queue_count[state].inspect}") }

      job_count = Job.nested_count_by(%w(state zone type))
      states = job_count.keys.sort_by { |k| k.to_s }
      states.each { |state| $log.info("#{log_prefix} [#{svr_name}] Job count for state=[#{state.inspect}] by zone and process_type: #{job_count[state].inspect}") }
    end
  end

end
