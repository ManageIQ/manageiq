class ManageIQ::Providers::Vmware::InfraManager::MetricsCapture < ManageIQ::Providers::BaseManager::MetricsCapture
  VIM_INTERVAL_NAME_BY_MIQ_INTERVAL_NAME = {'hourly' => 'Past Month'}
  MIQ_INTERVAL_NAME_BY_VIM_INTERVAL_NAME = VIM_INTERVAL_NAME_BY_MIQ_INTERVAL_NAME.invert

  #
  # MiqVimPerfHistory methods (with caching)
  #

  cache_with_timeout(:perf_history_results,
                     -> { (VMDB::Config.new("vmdb").config.fetch_path(:performance, :vim_cache_ttl) || 1.hour).to_i_with_method }
                    ) { Hash.new }

  def self.intervals(ems, vim_hist)
    phr = perf_history_results
    results = phr.fetch_path(:intervals, ems.id)
    return results unless results.nil?

    log_header = "EMS: [#{ems.hostname}]"
    begin
      results = vim_hist.intervals
    rescue Handsoap::Fault, StandardError => err
      _log.error("#{log_header} The following error occurred: [#{err}]")
      raise
    end

    _log.debug("#{log_header} Available sampling intervals: [#{results.length}]")
    phr.store_path(:intervals, ems.id, results)
  end

  def self.realtime_interval(ems, vim_hist, mor)
    phr = perf_history_results
    results = phr.fetch_path(:realtime_interval, ems.id, mor)
    return results unless results.nil?

    log_header = "EMS: [#{ems.hostname}]"

    begin
      summary = vim_hist.queryProviderSummary(mor)
    rescue Handsoap::Fault, StandardError => err
      _log.error("#{log_header} The following error occurred: [#{err}]")
      raise
    end

    if summary.kind_of?(Hash) && summary['currentSupported'].to_s == "true"
      interval = summary['refreshRate'].to_s
      _log.debug("#{log_header} Found realtime interval: [#{interval}] for mor: [#{mor}]")
    else
      interval = nil
      _log.debug("#{log_header} Realtime is not supported for mor: [#{mor}], summary: [#{summary.inspect}]")
    end

    phr.store_path(:realtime_interval, ems.id, mor, interval)
  end

  def self.hourly_interval(ems, vim_hist)
    phr = perf_history_results
    results = phr.fetch_path(:hourly_interval, ems.id)
    return results unless results.nil?

    log_header = "EMS: [#{ems.hostname}]"

    # Using the reporting value of 'hourly', get the vim interval 'Past Month'
    #   and look for that in the intervals data
    vim_interval = VIM_INTERVAL_NAME_BY_MIQ_INTERVAL_NAME['hourly']

    intervals = self.intervals(ems, vim_hist)

    interval = intervals.detect { |i| i['name'].to_s.downcase == vim_interval.downcase }
    if interval.nil?
      _log.debug("#{log_header} Unable to find hourly interval [#{vim_interval}] in intervals: #{intervals.collect { |i| i['name'] }.inspect}")
    else
      interval = interval['samplingPeriod'].to_s
      _log.debug("#{log_header} Found hourly interval: [#{interval}] for vim interval: [#{vim_interval}]")
    end

    phr.store_path(:hourly_interval, ems.id, interval)
  end

  def self.counter_info_by_counter_id(ems, vim_hist)
    phr = perf_history_results
    results = phr.fetch_path(:counter_info_by_id, ems.id)
    return results unless results.nil?

    log_header = "EMS: [#{ems.hostname}]"
    begin
      counter_info = vim_hist.id2Counter
    rescue Handsoap::Fault, StandardError => err
      _log.error("#{log_header} The following error occurred: [#{err}]")
      raise
    end

    # TODO: Move this to some generic parsing class, such as
    # ManageIQ::Providers::Vmware::InfraManager::RefreshParser
    results = counter_info.each_with_object({}) do |(id, c), h|
      group    = c.fetch_path('groupInfo', 'key').to_s.downcase
      name     = c.fetch_path('nameInfo', 'key').to_s.downcase
      rollup   = c['rollupType'].to_s.downcase
      stats    = c['statsType'].to_s.downcase
      unit_key = c.fetch_path('unitInfo', 'key').to_s.downcase

      h[id] = {
        :counter_key => "#{group}_#{name}_#{stats}_#{rollup}",
        :group       => group,
        :name        => name,
        :rollup      => rollup,
        :stats       => stats,
        :unit_key    => unit_key,
        :precision   => (unit_key == 'percent') ? 0.01 : 1,
      }
    end

    phr.store_path(:counter_info_by_id, ems.id, results)
  end

  def self.avail_metrics_for_entity(ems, vim_hist, mor, interval, interval_name)
    return {} if interval.nil?

    phr = perf_history_results
    results = phr.fetch_path(:avail_metrics_for_entity, ems.id, mor, interval)
    return results unless results.nil?

    log_header = "EMS: [#{ems.hostname}]"
    begin
      avail_metrics = vim_hist.availMetricsForEntity(mor, :intervalId => interval)
    rescue Handsoap::Fault, StandardError => err
      _log.error("#{log_header} The following error occurred: [#{err}]")
      raise
    end

    info = counter_info_by_counter_id(ems, vim_hist)

    results = avail_metrics.to_miq_a.each_with_object({}) do |metric, h|
      counter = info[metric["counterId"]]
      next if counter.nil?

      # Filter the metrics for only the cols we will use
      next unless Metric::Capture.capture_cols.include?(counter[:counter_key].to_sym)

      vim_key      = metric["counterId"].to_s
      instance     = metric["instance"].to_s
      full_vim_key = "#{vim_key}_#{instance}"

      h[full_vim_key] = {
        :counter_key           => counter[:counter_key],
        :rollup                => counter[:rollup],
        :precision             => counter[:precision],
        :unit_key              => counter[:unit_key],
        :vim_key               => vim_key,
        :instance              => instance,
        :capture_interval      => interval.to_s,
        :capture_interval_name => interval_name.to_s
      }
    end

    phr.store_path(:avail_metrics_for_entity, ems.id, mor, interval, results)
  end

  #
  # Processing/Converting methods
  #

  def self.preprocess_data(data, counter_values_by_mor_and_ts = {})
    # First process the results into a format we can consume
    processed_res = perf_raw_data_to_hashes(data)
    return unless processed_res.kind_of?(Array)

    # Next process each of the those results
    processed_res.each do |res|
      full_vim_key = "#{res[:counter_id]}_#{res[:instance]}"
      _log.debug("Processing [#{res[:results].length / 2}] results for MOR: [#{res[:mor]}], instance: [#{res[:instance]}], capture interval [#{res[:interval]}], counter vim key: [#{res[:counter_id]}]")

      hashes = perf_vim_data_to_hashes(res[:results])
      next if hashes.nil?
      hashes.each { |h| counter_values_by_mor_and_ts.store_path(res[:mor], h[:timestamp], full_vim_key, h[:counter_value]) }
    end
  end

  def self.perf_vim_data_to_hashes(vim_data)
    ret = []
    meth = nil

    # The data is organized in an array such as [timestamp1, value1, timestamp2, value2, ...]
    vim_data.to_miq_a.each_slice(2) do |t, v|
      if t.kind_of?(String) # VimString
        t = t.to_s
      else
        _log.warn("Discarding unexpected time value in results: ts: [#{t.class.name}] [#{t}], value: #{v}")
        next
      end
      ret << {:timestamp => t, :counter_value => v}
    end
    ret
  end

  def self.perf_raw_data_to_hashes(data)
    # Query perf with single instance single entity
    return [{:results => data}] if single_instance_and_entity?(data)

    # Query perf composite or Query perf with multiple instances, single entity
    return process_entity(data) if composite_or_multi_instance_and_single_entity?(data)

    # Query perf multi (multiple entities, instance(s))
    return data.collect { |base| process_entity(base) }.flatten if single_or_multi_instance_and_multi_entity?(data)
  end

  def self.single_instance_and_entity?(data)
    data.respond_to?(:first) && data.first.kind_of?(DateTime)
  end

  def self.composite_or_multi_instance_and_single_entity?(data)
    data.respond_to?(:has_key?) && data.key?('entity')
  end

  def self.single_or_multi_instance_and_multi_entity?(data)
    !single_instance_and_entity?(data) && data.respond_to?(:first)
  end

  def self.process_entity(data, parent = nil)
    mor = data['entity']

    # Set up the common attributes for each value in the result array
    base = {
      :mor      => mor,
      :children => []
    }
    base[:parent] = parent unless parent.nil?

    if data.key?('childEntity')
      raise 'composite is not supported yet'
      #      child_ar  = Array.new
      #      data['childEntity'].to_miq_a.each do |c|
      #        child_data = process_entity(c, mor)
      #        child_ar << child_data
      #        base[:children] << child_data[:mor]
      #      end
    end

    values = data['value'].to_miq_a
    samples = data['sampleInfo'].to_miq_a

    ret = []
    values.each do |v|
      id, v = v.values_at('id', 'value')

      nh = {}.merge!(base)
      nh[:counter_id] = id['counterId']
      nh[:instance]   = id['instance']

      nh[:results] = []
      samples.each_with_index do |s, i|
        nh[:interval] ||= s['interval']
        nh[:results] << s['timestamp']
        nh[:results] << v[i].to_i
      end

      ret << nh
    end
    ret
  end

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
      _log.error("#{@perf_resource} Failed to initialize performance history from #{@perf_ems}: [#{err}]")
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
    rescue Timeout::Error
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
                 when 'realtime' then self.class.realtime_interval(target.ext_management_system, @perf_vim_hist, mor)
                 when 'hourly'   then self.class.hourly_interval(target.ext_management_system, @perf_vim_hist)
                 end

      @perf_intervals[interval] = interval_name
      interval_by_mor[mor] = interval
    end

    _log.debug("Mapping of MOR to Intervals: #{interval_by_mor.inspect}")
    interval_by_mor
  end

  def perf_capture_counters(interval_by_mor)
    _log.info("Capturing counters...")

    counters_by_mor = {}

    # Query Vim for all of the available metrics and their associated counter info
    interval_by_mor.each do |mor, interval|
      counters_by_mor[mor] = self.class.avail_metrics_for_entity(target.ext_management_system, @perf_vim_hist, mor, interval, @perf_intervals[interval.to_s])
    end

    _log.info("Capturing counters...Complete")
    counters_by_mor
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
        :metricId   => counters.values.collect { |counter| {:counterId => counter[:vim_key], :instance => counter[:instance]} }
      }
      _log.debug("Adding query params: #{param.inspect}")
      params << param
    end

    _log.info("Building query parameters...Complete")

    params
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

      Benchmark.realtime_block(:perf_processing) { self.class.preprocess_data(data, counter_values_by_mor_and_ts) }
    end
    Benchmark.current_realtime[:num_vim_trips] = vim_trips

    counter_values_by_mor_and_ts
  end
end
