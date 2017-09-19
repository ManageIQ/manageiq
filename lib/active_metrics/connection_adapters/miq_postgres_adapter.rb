require 'active_metrics/connection_adapters/abstract_adapter'

module ActiveMetrics
  module ConnectionAdapters
    class MiqPostgresAdapter < AbstractAdapter
      include Vmdb::Logging

      # TODO Use the actual configuration from the initializer or whatever
      def self.create_connection(_config)
        ActiveRecord::Base.connection
      end

      def write_multiple(*metrics)
        Benchmark.realtime_block(:write_multiple) do
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
        klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)
        limiting_arel = klass.where(:capture_interval_name => interval_name).where(:resource => resource).where(:timestamp => start_time..end_time)

        samples_inventory_collection = ::ManagerRefresh::InventoryCollection.new(
          :manager_ref    => [:resource_type, :resource_id, :timestamp, :capture_interval_name],
          :name           => meth,
          :saver_strategy => :batch,
          :arel           => limiting_arel,
          :complete       => false,
          :model_class    => klass,
        )

        log_header = "[#{interval_name}]"

        # Read all the existing perfs for this time range to speed up lookups
        # TODO(lsmola) we need to fetch everything we have in DB first, because we process aligned 20s intervals, this
        # can go away once we remove the need for 20s intervals and processing based on that.
        obj_perfs, = Benchmark.realtime_block(:db_find_prev_perfs) do
          # TODO(lsmola) store just attributes, not whole AR objects here
          Metric::Finders.hash_by_capture_interval_name_and_timestamp(resource, start_time, end_time, interval_name)
        end

        # Create or update the performance rows from the hashes
        _log.info("#{log_header} Processing #{data.length} performance rows...")
        data.each do |v|
          ts = v[:timestamp]
          perf = nil

          Benchmark.realtime_block(:process_perfs) do
            if (perf = obj_perfs.fetch_path(interval_name, ts))
              v.reverse_merge!(perf.attributes.symbolize_keys)
              v.delete(:id) # Remove protected attributes
            end

            v[:resource_id] = resource.id
            v[:resource_type] = resource.class.base_class.name
            v.merge!(Metric::Processing.process_derived_columns(resource, v, interval_name == 'realtime' ? Metric::Helper.nearest_hourly_timestamp(ts) : nil))
            samples_inventory_collection.build(v)
          end
        end
        # Assign nil so GC can clean it up
        obj_perfs = nil

        Benchmark.realtime_block(:process_perfs_db) do
          ManagerRefresh::SaveInventory.save_inventory(ExtManagementSystem.first, [samples_inventory_collection])
        end
        created_count = samples_inventory_collection.created_records.count
        updated_count = samples_inventory_collection.updated_records.count
        # Assign nil so GC can clean it up
        samples_inventory_collection = nil

        if interval_name == 'hourly'
          # TODO(lsmola) pff, it needs AR objects, quite ineffective to batch here
          limiting_arel.find_each do |perf|
            Benchmark.realtime_block(:process_perfs_tag) { VimPerformanceTagValue.build_from_performance_record(perf) }
          end

          _log.info("#{log_header} Adding missing timestamp intervals...")
          Benchmark.realtime_block(:add_missing_intervals) { Metric::Processing.add_missing_intervals(resource, "hourly", start_time, end_time) }
          _log.info("#{log_header} Adding missing timestamp intervals...Complete")
        end

        _log.info("#{log_header} Processing #{data.length} performance rows...Complete - Added #{created_count} / Updated #{updated_count}")
      end
    end
  end
end
