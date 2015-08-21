module ManageIQ::Providers::Vmware::InfraManager::MetricsCalculations
  VIM_INTERVAL_NAME_BY_MIQ_INTERVAL_NAME = {'hourly' => 'Past Month'}
  MIQ_INTERVAL_NAME_BY_VIM_INTERVAL_NAME = VIM_INTERVAL_NAME_BY_MIQ_INTERVAL_NAME.invert

  #
  # MiqVimPerfHistory methods (with caching)
  #

  cache_with_timeout(:perf_history_results,
    lambda { (VMDB::Config.new("vmdb").config.fetch_path(:performance, :vim_cache_ttl) || 1.hour).to_i_with_method }
  ) { Hash.new }

  def self.intervals(ems, vim_hist)
    phr = self.perf_history_results
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
    return phr.store_path(:intervals, ems.id, results)
  end

  def self.realtime_interval(ems, vim_hist, mor)
    phr = self.perf_history_results
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

    return phr.store_path(:realtime_interval, ems.id, mor, interval)
  end

  def self.hourly_interval(ems, vim_hist)
    phr = self.perf_history_results
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

    return phr.store_path(:hourly_interval, ems.id, interval)
  end

  def self.counter_info_by_counter_id(ems, vim_hist)
    phr = self.perf_history_results
    results = phr.fetch_path(:counter_info_by_id, ems.id)
    return results unless results.nil?

    log_header = "EMS: [#{ems.hostname}]"
    begin
      counter_info = vim_hist.id2Counter
    rescue Handsoap::Fault, StandardError => err
      _log.error("#{log_header} The following error occurred: [#{err}]")
      raise
    end

    #TODO: Move this to some generic parsing class, such as
    #ManageIQ::Providers::Vmware::InfraManager::RefreshParser
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

    return phr.store_path(:counter_info_by_id, ems.id, results)
  end

  def self.avail_metrics_for_entity(ems, vim_hist, mor, interval, interval_name)
    return {} if interval.nil?

    phr = self.perf_history_results
    results = phr.fetch_path(:avail_metrics_for_entity, ems.id, mor, interval)
    return results unless results.nil?

    log_header = "EMS: [#{ems.hostname}]"
    begin
      avail_metrics = vim_hist.availMetricsForEntity(mor, :intervalId => interval)
    rescue Handsoap::Fault, StandardError => err
      _log.error("#{log_header} The following error occurred: [#{err}]")
      raise
    end

    info = self.counter_info_by_counter_id(ems, vim_hist)

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

    return phr.store_path(:avail_metrics_for_entity, ems.id, mor, interval, results)
  end

  #
  # Processing/Converting methods
  #

  def self.preprocess_data(data, counter_values_by_mor_and_ts = {})
    # First process the results into a format we can consume
    processed_res = self.perf_raw_data_to_hashes(data)
    return unless processed_res.kind_of?(Array)

    # Next process each of the those results
    processed_res.each do |res|
      full_vim_key = "#{res[:counter_id]}_#{res[:instance]}"
      _log.debug("Processing [#{res[:results].length / 2}] results for MOR: [#{res[:mor]}], instance: [#{res[:instance]}], capture interval [#{res[:interval]}], counter vim key: [#{res[:counter_id]}]")

      hashes = self.perf_vim_data_to_hashes(res[:results])
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
    return data.collect {|base| process_entity(base)}.flatten if single_or_multi_instance_and_multi_entity?(data)
  end

  private

  def self.single_instance_and_entity?(data)
    data.respond_to?(:first) && data.first.is_a?(DateTime)
  end

  def self.composite_or_multi_instance_and_single_entity?(data)
    data.respond_to?(:has_key?) && data.has_key?('entity')
  end

  def self.single_or_multi_instance_and_multi_entity?(data)
    !single_instance_and_entity?(data) && data.respond_to?(:first)
  end

  def self.process_entity(data, parent = nil)
    mor = data['entity']

    # Set up the common attributes for each value in the result array
    base = {
      :mor => mor,
      :children => []
    }
    base[:parent] = parent unless parent.nil?

    if data.has_key?('childEntity')
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
    return ret
  end
end
