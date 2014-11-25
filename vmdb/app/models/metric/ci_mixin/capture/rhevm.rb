module Metric::CiMixin::Capture::Rhevm
  #
  # Connect / Disconnect / Intialize methods
  #

  def perf_init_rhevm
    raise "no metrics credentials defined" unless self.ext_management_system.has_authentication_type?(:metrics)

    username, password = self.ext_management_system.auth_user_pwd(:metrics)

    conn_info = {
      :host     => self.ext_management_system.ipaddress,
      :database => self.ext_management_system.history_database_name,
      :username => username,
      :password => password
    }

    require 'ovirt_metrics'
    OvirtMetrics.establish_connection(conn_info)
  end

  def perf_release_rhevm
  end

  #
  # Capture methods
  #

  def perf_collect_metrics_rhevm(interval_name, start_time = nil, end_time = nil)
    objects = self.to_miq_a
    target = "[#{self.class.name}], [#{self.id}], [#{self.name}]"
    log_header = "MIQ(#{self.class.name}.perf_collect_metrics) [#{interval_name}] for: #{target}"

    start_time ||= 1.week.ago

    begin
      Benchmark.realtime_block(:rhevm_connect) { self.perf_init_rhevm }
      counters, = Benchmark.realtime_block(:collect_data) do
        case self
        when Host; OvirtMetrics.host_realtime(self.uid_ems, start_time, end_time)
        when Vm;   OvirtMetrics.vm_realtime(self.uid_ems, start_time, end_time)
        end
      end
      return *counters
    rescue Exception => err
      $log.error("#{log_header} Unhandled exception during perf data collection: [#{err}], class: [#{err.class}]")
      $log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      $log.log_backtrace(err)
      raise
    ensure
      self.perf_release_rhevm
    end
  end
end
