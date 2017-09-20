require 'active_metrics/connection_adapters/abstract_adapter'

module ActiveMetrics
  module ConnectionAdapters
    class MiqPostgresAdapter < AbstractAdapter
      include Vmdb::Logging

      # TODO Use the actual configuration from the initializer or whatever
      def self.create_connection(_config)
        ActiveRecord::Base.connection
      end

      def write_multiple(*params)
        resource, interval_name, start_time, end_time, data = params.first
        write_rows(interval_name, resource, start_time, end_time, data)
        data
      end

      def transform_parameters(resource, interval_name, start_time, end_time, rt_rows)
        obj_perfs, = Benchmark.realtime_block(:db_find_prev_perfs) do
          Metric::Finders.find_all_by_range(resource, start_time, end_time, interval_name).find_each.each_with_object({}) do |p, h|
            data, = Benchmark.realtime_block(:get_attributes) do
              p.attributes.delete_nils
            end
            h.store_path([p.resource_type, p.resource_id, p.capture_interval_name, p.timestamp.utc.iso8601], data.symbolize_keys)
          end
        end

        Benchmark.realtime_block(:process_perfs) do
          rt_rows.each do |ts, rt|
            rt[:resource_id] = resource.id
            rt[:resource_type] = resource.class.base_class.name

            if (perf = obj_perfs.fetch_path([rt[:resource_type], rt[:resource_id], interval_name, ts]))
              rt.reverse_merge!(perf)
              rt.delete(:id) # Remove protected attributes
            end

            rt.merge!(Metric::Processing.process_derived_columns(resource, rt, interval_name == 'realtime' ? Metric::Helper.nearest_hourly_timestamp(ts) : nil))
          end
        end
        # Assign nil so GC can clean it up
        obj_perfs = nil

        return resource, interval_name, start_time, end_time, rt_rows
      end

      private

      def write_rows(interval_name, resource, start_time, end_time, data)
        klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)
        samples_arel = klass.where(:capture_interval_name => interval_name).where(:resource => resource).where(:timestamp => start_time..end_time)

        samples_inventory_collection = ::ManagerRefresh::InventoryCollection.new(
          :manager_ref    => [:resource_type, :resource_id, :timestamp, :capture_interval_name],
          :name           => meth,
          :saver_strategy => :batch,
          :arel           => samples_arel,
          :complete       => false,
          :model_class    => klass,
        )

        log_header = "[#{interval_name}]"

        # Create or update the performance rows from the hashes
        _log.info("#{log_header} Processing #{data.length} performance rows...")
        data.each do |_ts, v|
          Benchmark.realtime_block(:process_build_ics) do
            samples_inventory_collection.build(v)
          end
        end

        Benchmark.realtime_block(:process_perfs_db) do
          ManagerRefresh::SaveInventory.save_inventory(ExtManagementSystem.first, [samples_inventory_collection])
        end
        created_count = samples_inventory_collection.created_records.count
        updated_count = samples_inventory_collection.updated_records.count
        # Assign nil so GC can clean it up
        samples_inventory_collection = nil

        if interval_name == 'hourly'
          # TODO(lsmola) pff, it needs AR objects, quite ineffective to batch here
          samples_arel.find_each do |perf|
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
