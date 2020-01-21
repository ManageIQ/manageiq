require 'miq-system'

module MiqServer::StatusManagement
  extend ActiveSupport::Concern

  def status_update
    assign_attributes(system_status)
    assign_attributes(process_status)
    save!
  end

  def system_status
    sys = MiqSystem.memory
    {
      :system_memory_free => sys.fetch(:MemFree, 0),
      :system_memory_used => sys.fetch(:MemTotal, 0) - sys.fetch(:MemFree, 0),
      :system_swap_free   => sys.fetch(:SwapFree, 0),
      :system_swap_used   => sys.fetch(:SwapTotal, 0) - sys.fetch(:SwapFree, 0)
    }
  end

  def process_status
    require 'miq-process'
    pinfo = MiqProcess.processInfo(pid)
    # Ensure the hash only contains the values we want to store in the table
    pinfo.keep_if { |k, _v| MiqWorker::PROCESS_INFO_FIELDS.include?(k) }
    pinfo[:os_priority] = pinfo.delete(:priority)
    pinfo
  end

  module ClassMethods
    # TODO: Delegate class methods to instance methods.
    # 1. Create instance methods
    # 2. Delegate and/or deprecate these class methods
    # 3. Change callers (app/models/miq_schedule_worker/jobs.rb) to use an instance.
    # 4. Cleanup any existing queue messages.
    def status_update
      my_server.status_update
    end

    def log_status
      log_system_status
      svr = my_server(true)
      _log.info("[#{svr.friendly_name}] Process info: Memory Usage [#{svr.memory_usage}], Memory Size [#{svr.memory_size}], Proportional Set Size: [#{svr.proportional_set_size}], Unique Set Size: [#{svr.unique_set_size}], Memory % [#{svr.percent_memory}], CPU Time [#{svr.cpu_time}], CPU % [#{svr.percent_cpu}], Priority [#{svr.os_priority}]") unless svr.nil?
    end

    def log_system_status
      svr        = my_server
      svr_name   = svr ? svr.friendly_name : "EVM Server (Unidentified)"

      status = MiqSystem.memory
      unless status.empty?
        _log.info("[#{svr_name}] System Status:")
        status.keys.sort_by(&:to_s).each { |k| _log.info("[#{svr_name}]     #{k}: #{status[k]}") }
      end

      disks = MiqSystem.disk_usage
      unless disks.empty?
        _log.info("[#{svr_name}] Disk Usage:")
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
        _log.info("[#{svr_name}] #{header}")

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
          _log.info("[#{svr_name}] #{formatted}")
        end

        # Raise events if disk usage above threshold
        svr.check_disk_usage(disks)
      end

      queue_count = MiqQueue.nested_count_by(%w(state zone role))
      states = queue_count.keys.sort_by(&:to_s)
      states.each { |state| _log.info("[#{svr_name}] MiqQueue count for state=[#{state.inspect}] by zone and role: #{queue_count[state].inspect}") }

      job_count = Job.nested_count_by(%w(state zone type))
      states = job_count.keys.sort_by(&:to_s)
      states.each { |state| _log.info("[#{svr_name}] Job count for state=[#{state.inspect}] by zone and process_type: #{job_count[state].inspect}") }
    end
  end
end
