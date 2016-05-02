class ManageIQ::Providers::Redhat::InfraManager::MetricsCapture < ManageIQ::Providers::BaseManager::MetricsCapture
  #
  # Connect / Disconnect / Intialize methods
  #

  def perf_init_rhevm
    raise "no metrics credentials defined" unless target.ext_management_system.has_authentication_type?(:metrics)

    username, password = target.ext_management_system.auth_user_pwd(:metrics)

    conn_info = {
      :host     => target.ext_management_system.connection_configuration_by_role('metrics').endpoint.hostname,
      :database => target.ext_management_system.history_database_name,
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

  def perf_collect_metrics(interval_name, start_time = nil, end_time = nil)
    log_header = "[#{interval_name}] for: [#{target.class.name}], [#{target.id}], [#{target.name}]"

    start_time ||= 1.week.ago

    begin
      Benchmark.realtime_block(:rhevm_connect) { perf_init_rhevm }
      counters, = Benchmark.realtime_block(:collect_data) do
        case target
        when Host then OvirtMetrics.host_realtime(target.uid_ems, start_time, end_time)
        when Vm then   OvirtMetrics.vm_realtime(target.uid_ems, start_time, end_time)
        end
      end
      return counters
    rescue Exception => err
      _log.error("#{log_header} Unhandled exception during perf data collection: [#{err}], class: [#{err.class}]")
      _log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      _log.log_backtrace(err)
      raise
    ensure
      perf_release_rhevm
    end
  end
end
