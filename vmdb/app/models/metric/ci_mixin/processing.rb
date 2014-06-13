module Metric::CiMixin::Processing
  def perf_process(interval_name, start_time, end_time, counters, counter_values)
    raise ArgumentError, "invalid interval_name '#{interval_name}'" unless Metric::Capture::VALID_CAPTURE_INTERVALS.include?(interval_name)

    log_header = "MIQ(#{self.class.name}.perf_process) [#{interval_name}]"
    log_target = "#{self.class.name} name: [#{self.name}], id: [#{self.id}]"

    interval_orig = interval_name
    interval_name = 'hourly' if interval_name == 'historical'

    affected_timestamps = []
    $log.info("#{log_header} Processing for #{log_target}, for range [#{start_time} - #{end_time}]...")

    dummy, t = Benchmark.realtime_block(:total_time) do
      # Take the raw metrics and create hashes out of them
      rt_rows = {}
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
              $log.debug("#{log_header} Column [#{col}] is not defined, skipping")
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
                :resource_name         => self.name,
                :timestamp             => ts
              })
            rt[col], message = Metric::Helper.normalize_value(value, counter)
            $log.warn("#{log_header} #{log_target} Timestamp: [#{ts}], Column [#{col}]: '#{message}'") if message
          end
        end
      end

      # Read all the existing perfs for this time range to speed up lookups
      obj_perfs, = Benchmark.realtime_block(:db_find_prev_perfs) do
        Metric::Finders.hash_by_capture_interval_name_and_timestamp(self, start_time, end_time, interval_name)
      end

      klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)

      # Create or update the performance rows from the hashes
      $log.info("#{log_header} Processing #{rt_rows.length} performance rows...")
      a = u = 0
      rt_rows.each do |ts, v|
        perf = nil

        Benchmark.realtime_block(:process_perfs) do
          perf = obj_perfs.fetch_path(interval_name, ts)
          perf ||= obj_perfs.store_path(interval_name, ts, self.send(meth).build(:resource_name => self.name))
          perf.new_record? ? a += 1 : u += 1

          v.reverse_merge!(perf.attributes)
          v.delete("id") # Remove protected attributes
          v.merge!(Metric::Processing.process_derived_columns(self, v, interval_name == 'realtime' ? Metric::Helper.nearest_hourly_timestamp(ts) : nil))
        end

        #TODO: Should we change this into a single metrics.push like we do in ems_refresh?
        Benchmark.realtime_block(:process_perfs_db) { perf.update_attributes(v) }

        if interval_name == 'hourly'
          Benchmark.realtime_block(:process_perfs_tag) { VimPerformanceTagValue.build_from_performance_record(perf) }
        end
      end

      self.update_attribute(:last_perf_capture_on, end_time) if self.last_perf_capture_on.nil? || self.last_perf_capture_on.utc.iso8601 < end_time
      $log.info("#{log_header} Processing #{rt_rows.length} performance rows...Complete - Added #{a} / Updated #{u}")

      if interval_name == 'hourly'
        $log.info("#{log_header} Adding missing timestamp intervals...")
        Benchmark.realtime_block(:add_missing_intervals) { Metric::Processing.add_missing_intervals(self, "hourly", start_time, end_time) }
        $log.info("#{log_header} Adding missing timestamp intervals...Complete")
      end

      # Raise <class>_perf_complete alert event if realtime so alerts can be evaluated.
      MiqEvent.raise_evm_alert_event_queue(self, MiqEvent.event_name_for_target(self, "perf_complete"))

      self.perf_rollup_to_parent(interval_orig, start_time, end_time)
    end
    $log.info("#{log_header} Processing for #{log_target}, for range [#{start_time} - #{end_time}]...Complete - Timings: #{t.inspect}")

    return affected_timestamps
  end
end
