module Metric::CiMixin::Capture::Vim
  #
  # Connect / Disconnect / Intialize methods
  #

  def perf_init_vim
    @perf_resource = "Resource: [#{self.class.name}], id: [#{self.id}]"
    ems = self.ext_management_system
    raise "#{@perf_resource} is not connected to an EMS" if ems.nil?

    @perf_intervals = {}
    @perf_ems       = "EMS: [#{ems.ipaddress}]"

    log_header = "MIQ(#{self.class.name}.perf_init) #{@perf_resource}"
    begin
      @perf_vim = self.ext_management_system.connect
      @perf_vim_hist = @perf_vim.getVimPerfHistory
    rescue => err
      $log.error("#{log_header} Failed to initialize performance history from #{@perf_ems}: [#{err}]" )
      self.perf_release_vim
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

  def perf_collect_metrics_vim(interval_name, start_time = nil, end_time = nil)
    objects = self.to_miq_a
    target = "[#{self.class.name}], [#{self.id}], [#{self.name}]"
    log_header = "MIQ(#{self.class.name}#perf_collect_metrics) [#{interval_name}] for: #{target}"

    require 'httpclient'

    begin
      Benchmark.realtime_block(:vim_connect) { self.perf_init_vim }

      objects_by_mor   = objects.each_with_object({}) { |o, h| h[o.ems_ref_obj] = o }
      interval_by_mor, = Benchmark.realtime_block(:capture_intervals)  { self.perf_capture_intervals(objects_by_mor.keys, interval_name) }
      counters_by_mor, = Benchmark.realtime_block(:capture_counters)   { self.perf_capture_counters(interval_by_mor) }
      query_params,    = Benchmark.realtime_block(:build_query_params) { self.perf_build_query_params(interval_by_mor, counters_by_mor, start_time, end_time) }
      counter_values_by_mor_and_ts = self.perf_query(query_params, interval_name)

      return counters_by_mor, counter_values_by_mor_and_ts
    rescue HTTPClient::ReceiveTimeoutError => err
      attempts ||= 0
      msg = "#{log_header} Timeout Error during metrics data collection: [#{err}], class: [#{err.class}]"
      if attempts < 3
        attempts += 1
        $log.warn("#{msg}...Retry attempt [#{attempts}]")
        $log.warn("#{log_header}   Timings before retry: #{Benchmark.current_realtime.inspect}")
        self.perf_release_vim
        retry
      end

      $log.error("#{msg}...Failed after [#{attempts}] retry attempts")
      $log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      raise MiqException::MiqCommunicationsTimeoutError, err.message
    rescue TimeoutError
      $log.error("#{log_header} Timeout Error during metrics data collection")
      $log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      raise MiqException::MiqTimeoutError, err.message
    rescue Errno::ECONNREFUSED => err
      $log.error("#{log_header} Communications Error during metrics data collection: [#{err}], class: [#{err.class}]")
      $log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      raise MiqException::MiqConnectionRefusedError, err.message
    rescue Exception => err
      $log.error("#{log_header} Unhandled exception during metrics data collection: [#{err}], class: [#{err.class}]")
      $log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      $log.log_backtrace(err)
      raise
    ensure
      self.perf_release_vim
    end
  end

  def perf_capture_intervals(mors, interval_name)
    interval_by_mor = {}
    mors.each do |mor|
      interval = case interval_name
      when 'realtime' then Metric::Capture::Vim.realtime_interval(self.ext_management_system, @perf_vim_hist, mor)
      when 'hourly'   then Metric::Capture::Vim.hourly_interval(self.ext_management_system, @perf_vim_hist)
      end

      @perf_intervals[interval] = interval_name
      interval_by_mor[mor] = interval
    end

    $log.debug("MIQ(#{self.class.name}.perf_capture_intervals) Mapping of MOR to Intervals: #{interval_by_mor.inspect}")
    return interval_by_mor
  end

  def perf_capture_counters(interval_by_mor)
    log_header = "MIQ(#{self.class.name}.perf_capture_counters)"
    $log.info("#{log_header} Capturing counters...")

    counters_by_mor = {}

    # Query Vim for all of the available metrics and their associated counter info
    interval_by_mor.each do |mor, interval|
      counters_by_mor[mor] = Metric::Capture::Vim.avail_metrics_for_entity(self.ext_management_system, @perf_vim_hist, mor, interval, @perf_intervals[interval.to_s])
    end

    $log.info("#{log_header} Capturing counters...Complete")
    return counters_by_mor
  end

  def perf_build_query_params(interval_by_mor, counters_by_mor, start_time, end_time)
    log_header = "MIQ(#{self.class.name}.perf_build_query_params)"
    $log.info("#{log_header} Building query parameters...")

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
      $log.debug("#{log_header} Adding query params: #{param.inspect}")
      params << param
    end

    $log.info("#{log_header} Building query parameters...Complete")

    return params
  end

  def perf_query(params, interval_name)
    counter_values_by_mor_and_ts = {}
    return counter_values_by_mor_and_ts if params.blank?

    log_header = "MIQ(#{self.class.name}.perf_query)"

    Benchmark.current_realtime[:num_vim_queries] = params.length
    $log.debug("#{log_header} Total item(s) to be requested: [#{params.length}], #{params.inspect}")

    query_size = Metric::Capture.concurrent_requests(interval_name)
    vim_trips = 0
    params.each_slice(query_size) do |query|
      vim_trips += 1

      $log.debug("#{log_header} Starting request for [#{query.length}] item(s), #{query.inspect}")
      data, = Benchmark.realtime_block(:vim_execute_time) { @perf_vim_hist.queryPerfMulti(query) }
      $log.debug("#{log_header} Finished request for [#{query.length}] item(s)")

      Benchmark.realtime_block(:perf_processing) { Metric::Capture::Vim.preprocess_data(data, counter_values_by_mor_and_ts) }
    end
    Benchmark.current_realtime[:num_vim_trips] = vim_trips

    return counter_values_by_mor_and_ts
  end



end
