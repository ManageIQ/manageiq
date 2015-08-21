class ManageIQ::Providers::Vmware::InfraManager::MetricsCapture < ManageIQ::Providers::BaseManager::MetricsCapture
  #
  # Connect / Disconnect / Intialize methods
  #

  def perf_init_vim
    @perf_resource = "Resource: [#{target.class.name}], id: [#{target.id}]"
    ems = target.ext_management_system
    raise "#{@perf_resource} is not connected to an EMS" if ems.nil?

    @perf_intervals = {}
    @perf_ems       = "EMS: [#{ems.hostname}]"

    begin
      @perf_vim = target.ext_management_system.connect
      @perf_vim_hist = @perf_vim.getVimPerfHistory
    rescue => err
      _log.error("#{@perf_resource} Failed to initialize performance history from #{@perf_ems}: [#{err}]" )
      perf_release_vim
      raise
    end
  end

  def perf_release_vim
    @perf_vim_hist.release if @perf_vim_hist rescue nil
    @perf_vim.disconnect   if @perf_vim      rescue nil
    @perf_vim_hist = @perf_vim = nil
  end

  #
  # Capture methods
  #

  def perf_collect_metrics(interval_name, start_time = nil, end_time = nil)
    objects = target.to_miq_a
    log_header = "[#{interval_name}] for: [#{target.class.name}], [#{target.id}], [#{target.name}]"

    require 'httpclient'

    begin
      Benchmark.realtime_block(:vim_connect) { perf_init_vim }

      objects_by_mor   = objects.each_with_object({}) { |o, h| h[o.ems_ref_obj] = o }
      interval_by_mor, = Benchmark.realtime_block(:capture_intervals)  { perf_capture_intervals(objects_by_mor.keys, interval_name) }
      counters_by_mor, = Benchmark.realtime_block(:capture_counters)   { perf_capture_counters(interval_by_mor) }
      query_params,    = Benchmark.realtime_block(:build_query_params) { perf_build_query_params(interval_by_mor, counters_by_mor, start_time, end_time) }
      counter_values_by_mor_and_ts = perf_query(query_params, interval_name)

      return counters_by_mor, counter_values_by_mor_and_ts
    rescue HTTPClient::ReceiveTimeoutError => err
      attempts ||= 0
      msg = "#{log_header} Timeout Error during metrics data collection: [#{err}], class: [#{err.class}]"
      if attempts < 3
        attempts += 1
        _log.warn("#{msg}...Retry attempt [#{attempts}]")
        _log.warn("#{log_header}   Timings before retry: #{Benchmark.current_realtime.inspect}")
        perf_release_vim
        retry
      end

      _log.error("#{msg}...Failed after [#{attempts}] retry attempts")
      _log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      raise MiqException::MiqCommunicationsTimeoutError, err.message
    rescue TimeoutError
      _log.error("#{log_header} Timeout Error during metrics data collection")
      _log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      raise MiqException::MiqTimeoutError, err.message
    rescue Errno::ECONNREFUSED => err
      _log.error("#{log_header} Communications Error during metrics data collection: [#{err}], class: [#{err.class}]")
      _log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      raise MiqException::MiqConnectionRefusedError, err.message
    rescue Exception => err
      _log.error("#{log_header} Unhandled exception during metrics data collection: [#{err}], class: [#{err.class}]")
      _log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      _log.log_backtrace(err)
      raise
    ensure
      perf_release_vim
    end
  end

  def perf_capture_intervals(mors, interval_name)
    interval_by_mor = {}
    mors.each do |mor|
      interval = case interval_name
      when 'realtime' then ManageIQ::Providers::Vmware::InfraManager::MetricsCalculations.realtime_interval(target.ext_management_system, @perf_vim_hist, mor)
      when 'hourly'   then ManageIQ::Providers::Vmware::InfraManager::MetricsCalculations.hourly_interval(target.ext_management_system, @perf_vim_hist)
      end

      @perf_intervals[interval] = interval_name
      interval_by_mor[mor] = interval
    end

    _log.debug("Mapping of MOR to Intervals: #{interval_by_mor.inspect}")
    return interval_by_mor
  end

  def perf_capture_counters(interval_by_mor)
    _log.info("Capturing counters...")

    counters_by_mor = {}

    # Query Vim for all of the available metrics and their associated counter info
    interval_by_mor.each do |mor, interval|
      counters_by_mor[mor] = ManageIQ::Providers::Vmware::InfraManager::MetricsCalculations.avail_metrics_for_entity(target.ext_management_system, @perf_vim_hist, mor, interval, @perf_intervals[interval.to_s])
    end

    _log.info("Capturing counters...Complete")
    return counters_by_mor
  end

  def perf_build_query_params(interval_by_mor, counters_by_mor, start_time, end_time)
    _log.info("Building query parameters...")

    params = []
    interval_by_mor.each do |mor, interval|
      counters = counters_by_mor[mor]
      next if counters.empty?

      st, et = Metric::Helper.sanitize_start_end_time(interval, @perf_intervals[interval.to_s], start_time, end_time)

      param = {
        :entity     => mor,
        :intervalId => interval,
        :startTime  => st,
        :endTime    => et,
        :metricId   => counters.values.collect { |counter| { :counterId => counter[:vim_key], :instance => counter[:instance] } }
      }
      _log.debug("Adding query params: #{param.inspect}")
      params << param
    end

    _log.info("Building query parameters...Complete")

    return params
  end

  def perf_query(params, interval_name)
    counter_values_by_mor_and_ts = {}
    return counter_values_by_mor_and_ts if params.blank?

    Benchmark.current_realtime[:num_vim_queries] = params.length
    _log.debug("Total item(s) to be requested: [#{params.length}], #{params.inspect}")

    query_size = Metric::Capture.concurrent_requests(interval_name)
    vim_trips = 0
    params.each_slice(query_size) do |query|
      vim_trips += 1

      _log.debug("Starting request for [#{query.length}] item(s), #{query.inspect}")
      data, = Benchmark.realtime_block(:vim_execute_time) { @perf_vim_hist.queryPerfMulti(query) }
      _log.debug("Finished request for [#{query.length}] item(s)")

      Benchmark.realtime_block(:perf_processing) { ManageIQ::Providers::Vmware::InfraManager::MetricsCalculations.preprocess_data(data, counter_values_by_mor_and_ts) }
    end
    Benchmark.current_realtime[:num_vim_trips] = vim_trips

    return counter_values_by_mor_and_ts
  end
end
