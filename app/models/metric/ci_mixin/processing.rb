module Metric::CiMixin::Processing
  def perf_process(interval_name, start_time, end_time, counters_data)
    unless Metric::Capture::VALID_CAPTURE_INTERVALS.include?(interval_name)
      raise ArgumentError, _("invalid interval_name '%{name}'") % {:name => interval_name}
    end

    log_header = "[#{interval_name}]"

    interval_orig = interval_name
    interval_name = 'hourly' if interval_name == 'historical'

    affected_timestamps = []

    # Fetch ActiveRecord object by 1 query per Model
    grouped_resource_refs = counters_data.keys.each_with_object({}) { |x, obj| (obj[x.first] ||= []) << x.second }
    fetched_records = grouped_resource_refs.keys.each_with_object({}) do |x, obj|
      x.constantize.where(:id => grouped_resource_refs[x]).each { |rec| obj[[x, rec.id]] = rec }
    end
    # Transforming [Class, id] that were sent via the counters_data into the ActiveRecord objects
    counters_data.transform_keys! { |x| fetched_records[x] }
    resources = counters_data.keys

    _log.info("#{log_header} Processing for #{log_specific_targets(resources)}, for range [#{start_time} - #{end_time}]...")

    dummy, t = Benchmark.realtime_block(:total_time) do
      # Take the raw metrics and create hashes out of them
      rt_rows = {}

      counters_data.each do |resource, data|
        counters       = data[:counters]
        counter_values = data[:counter_values]

        Benchmark.realtime_block(:process_counter_values) do
          counter_values.each do |ts, cv|
            affected_timestamps << ts
            ts = Metric::Helper.nearest_realtime_timestamp(ts) if interval_name == 'realtime'

            col_vals = {}
            cv.each do |counter_id, value|
              counter = counters[counter_id]
              next if counter.nil? || counter[:capture_interval_name] != interval_name

              col = counter[:counter_key].to_sym
              unless Metric.column_names_symbols.include?(col)
                _log.debug("#{log_header} Column [#{col}] is not defined, skipping")
                next
              end

              col_vals.store_path(col, counter[:instance], [value, counter])
            end

            col_vals.each do |col, values_by_instance|
              # If there are multiple instances for a column, use the aggregate
              #   instance, if available, otherwise roll it up ourselves.
              value, counter = values_by_instance[""]
              if value.nil?
                value = 0
                counter = nil
                values_by_instance.each_value { |v, c| value += v; counter = c }
              end

              # Create the hashes for the rows
              rt = (rt_rows[ts] ||= {
                :capture_interval_name => interval_name,
                :capture_interval      => counter[:capture_interval],
                :resource              => resource,
                :resource_name         => resource.name,
                :timestamp             => ts
              })
              rt[col], message = normalize_value(value, counter)
              _log.warn("#{log_header} #{log_target} Timestamp: [#{ts}], Column [#{col}]: '#{message}'") if message
            end
          end
        end
      end

      ActiveMetrics::Base.connection.write_multiple(
        ActiveMetrics::Base.connection.transform_parameters(resources, interval_name, start_time, end_time, rt_rows)
      )

      resources.each do |resource|
        resource.update_attribute(:last_perf_capture_on, end_time) if resource.last_perf_capture_on.nil? || resource.last_perf_capture_on.utc.iso8601 < end_time
      end

      # Raise <class>_perf_complete alert event if realtime so alerts can be evaluated.
      resources.each do |resource|
        MiqEvent.raise_evm_alert_event_queue(resource, MiqEvent.event_name_for_target(resource, "perf_complete"))
      end

      resources.each do |resource|
        resource.perf_rollup_to_parents(interval_orig, start_time, end_time)
      end
    end
    _log.info("#{log_header} Processing for #{log_specific_targets(resources)}, for range [#{start_time} - #{end_time}]...Complete - Timings: #{t.inspect}")

    affected_timestamps
  end

  private

  def normalize_value(value, counter)
    return counter[:rollup] == 'latest' ? nil : 0 if value < 0
    value = value.to_f * counter[:precision]

    message = nil
    percent_norm = 100.0
    if counter[:unit_key] == "percent" && value > percent_norm
      message = "percent value #{value} is out of range, resetting to #{percent_norm}"
      value = percent_norm
    end
    return value, message
  end
end
