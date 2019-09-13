require 'active_metrics/connection_adapters/abstract_adapter'

module ActiveMetrics
  module ConnectionAdapters
    class MiqPostgresLegacyAdapter < AbstractAdapter
      include Vmdb::Logging

      # TODO Use the actual configuration from the initializer or whatever
      def self.create_connection(_config)
        ActiveRecord::Base.connection
      end

      def write_multiple(*metrics)
        metrics.flatten!

        flatten_metrics(metrics).each do |interval_name, by_resource|
          by_resource.each do |resource, by_timestamp|
            start_time = by_timestamp.keys.min
            end_time   = by_timestamp.keys.max
            data       = by_timestamp.values
            write_rows(interval_name, resource, start_time, end_time, data)
          end
        end

        metrics
      end

      private

      def flatten_metrics(metrics)
        {}.tap do |index|
          metrics.each do |m|
            interval_name = m.fetch_path(:tags, :capture_interval_name)
            resource = m[:resource] || m.fetch_path(:tags, :resource_type).safe_constantize.find(m.fetch_path(:tags, :resource_id))
            fields = index.fetch_path(interval_name, resource, m[:timestamp]) || m[:tags].symbolize_keys.except(:resource_type, :resource_id).merge(:timestamp => m[:timestamp])
            fields[m[:metric_name].to_sym] = m[:value]
            index.store_path(interval_name, resource, m[:timestamp], fields)
          end
        end
      end

      def write_rows(interval_name, resource, start_time, end_time, data)
        log_header = "[#{interval_name}]"

        # Read all the existing perfs for this time range to speed up lookups
        obj_perfs, = Benchmark.realtime_block(:db_find_prev_perfs) do
          Metric::Finders.hash_by_capture_interval_name_and_timestamp(resource, start_time, end_time, interval_name)
        end

        _klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)

        # Create or update the performance rows from the hashes
        _log.info("#{log_header} Processing #{data.length} performance rows...")
        a = u = 0
        data.each do |v|
          ts = v[:timestamp]
          perf = nil

          Benchmark.realtime_block(:process_perfs) do
            perf = obj_perfs.fetch_path(interval_name, ts)
            perf ||= obj_perfs.store_path(interval_name, ts, resource.send(meth).build(:resource_name => resource.name))
            perf.new_record? ? a += 1 : u += 1

            v.reverse_merge!(perf.attributes.symbolize_keys)
            v.delete("id") # Remove protected attributes
            v.merge!(Metric::Processing.process_derived_columns(resource, v, interval_name == 'realtime' ? Metric::Helper.nearest_hourly_timestamp(ts) : nil))
          end

          # TODO: Should we change this into a single metrics.push like we do in ems_refresh?
          Benchmark.realtime_block(:process_perfs_db) { perf.update(v) }
        end

        if interval_name == 'hourly'
          _log.info("#{log_header} Adding missing timestamp intervals...")
          Benchmark.realtime_block(:add_missing_intervals) { Metric::Processing.add_missing_intervals(resource, "hourly", start_time, end_time) }
          _log.info("#{log_header} Adding missing timestamp intervals...Complete")
        end

        _log.info("#{log_header} Processing #{data.length} performance rows...Complete - Added #{a} / Updated #{u}")
      end
    end
  end
end
