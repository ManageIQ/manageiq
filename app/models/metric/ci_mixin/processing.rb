module Metric::CiMixin::Processing
  def perf_process(interval_name, start_time, end_time, counters_data)
    unless Metric::Capture::VALID_CAPTURE_INTERVALS.include?(interval_name)
      raise ArgumentError, _("invalid interval_name '%{name}'") % {:name => interval_name}
    end

    log_header = "[#{interval_name}]"

    interval_orig = interval_name
    interval_name = 'hourly' if interval_name == 'historical'

    affected_timestamps = []

    transform_resources!(counters_data)
    resources = counters_data.keys

    _log.info("#{log_header} Processing for #{log_specific_targets(resources)}, for range [#{start_time} - #{end_time}]...")

    _dummy, t = Benchmark.realtime_block(:total_time) do
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
                values_by_instance.each_value do |v, c|
                  value += v
                  counter = c
                end
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

      parameters = if ActiveMetrics::Base.connection_config[:adapter] == "miq_postgres"
                     # We can just pass original data to PG, with metrics grouped by timestamps, since that is how
                     # we store to PG now. It will spare quite some memory and time to not convert it to row_per_metric
                     # and than back to original format.
                     transform_parameters_row_with_all_metrics(resources, interval_name, start_time, end_time, rt_rows)
                   else
                     transform_parameters_row_per_metric(resources, interval_name, start_time, end_time, rt_rows)
                   end

      ActiveMetrics::Base.connection.write_multiple(parameters)

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

      publish_metrics(rt_rows)
    end
    _log.info("#{log_header} Processing for #{log_specific_targets(resources)}, for range [#{start_time} - #{end_time}]...Complete - Timings: #{t.inspect}")

    affected_timestamps
  end

  private

  def transform_resources!(counters_data)
    # Fetch ActiveRecord object by 1 query per Model
    grouped_resource_refs = counters_data.keys.each_with_object({}) { |x, obj| (obj[x.first] ||= []) << x.second }
    fetched_records = grouped_resource_refs.keys.each_with_object({}) do |x, obj|
      x.constantize.where(:id => grouped_resource_refs[x]).each { |rec| obj[[x, rec.id]] = rec }
    end
    # Transforming [Class, id] that were sent via the counters_data into the ActiveRecord objects
    counters_data.transform_keys! { |x| fetched_records[x] }
  end

  def transform_parameters_row_per_metric(_resources, interval_name, _start_time, _end_time, rt_rows)
    rt_rows.flat_map do |ts, rt|
      rt.merge!(Metric::Processing.process_derived_columns(rt[:resource], rt, interval_name == 'realtime' ? Metric::Helper.nearest_hourly_timestamp(ts) : nil))
      rt.delete_nils
      rt_tags   = rt.slice(:capture_interval_name, :capture_interval, :resource_name).symbolize_keys
      rt_fields = rt.except(:capture_interval_name,
                            :capture_interval,
                            :resource_name,
                            :timestamp,
                            :instance_id,
                            :class_name,
                            :resource,
                            :resource_type,
                            :resource_id)

      rt_fields.map do |k, v|
        {
          :timestamp   => ts,
          :metric_name => k,
          :value       => v,
          :resource    => rt[:resource],
          :tags        => rt_tags
        }
      end
    end
  end

  def transform_parameters_row_with_all_metrics(resources, interval_name, start_time, end_time, rt_rows)
    obj_perfs, = Benchmark.realtime_block(:db_find_prev_perfs) do
      Metric::Finders.find_all_by_range(resources, start_time, end_time, interval_name).find_each.each_with_object({}) do |p, h|
        data, = Benchmark.realtime_block(:get_attributes) do
          # TODO(lsmola) calling .attributes takes more time than actually saving all the samples, try to fetch pure
          # arrays from the PG
          p.attributes.delete_nils
        end
        h.store_path([p.resource_type, p.resource_id, p.capture_interval_name, p.timestamp.utc.iso8601], data.symbolize_keys)
      end
    end

    Benchmark.realtime_block(:preload_vim_performance_state_for_ts) do
      # Make sure we preload all vim_performance_state_for_ts to avoid n+1 queries
      condition = if start_time.nil?
                    nil
                  elsif start_time == end_time
                    {:timestamp => start_time}
                  elsif end_time.nil?
                    VimPerformanceState.arel_table[:timestamp].gteq(start_time)
                  else
                    {:timestamp => start_time..end_time}
                  end

      resources.each { |r| r.preload_vim_performance_state_for_ts_iso8601(condition) }
    end

    Benchmark.realtime_block(:process_perfs) do
      rt_rows.each do |ts, rt|
        rt[:resource_id]   = rt[:resource].id
        rt[:resource_type] = rt[:resource].class.base_class.name

        if (perf = obj_perfs.fetch_path([rt[:resource_type], rt[:resource_id], interval_name, ts]))
          rt.reverse_merge!(perf)
          rt.delete(:id) # Remove protected attributes
        end

        rt.merge!(Metric::Processing.process_derived_columns(rt[:resource], rt, interval_name == 'realtime' ? Metric::Helper.nearest_hourly_timestamp(ts) : nil))
      end
    end
    # Assign nil so GC can clean it up
    obj_perfs = nil

    return resources, interval_name, start_time, end_time, rt_rows
  end

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

  def publish_metrics(metrics)
    return if MiqQueue.messaging_type == "miq_queue"

    metrics.each_value do |metric|
      resource = metric.delete(:resource)

      metric[:parent_ems_type] = resource.ext_management_system&.class&.ems_type
      metric[:parent_ems_uid]  = resource.ext_management_system&.uid_ems

      metric[:resource_type] = resource.class.base_class.name
      metric[:resource_id]   = resource.id

      metric[:resource_manager_ref] = resource.ems_ref if resource.respond_to?(:ems_ref)
      metric[:resource_manager_uid] = resource.uid_ems if resource.respond_to?(:uid_ems)

      MiqQueue.messaging_client("metrics_capture")&.publish_topic(
        :service => "manageiq.metrics",
        :sender  => resource.ext_management_system&.id,
        :event   => "metrics",
        :payload => metric
      )
    end
  end
end
