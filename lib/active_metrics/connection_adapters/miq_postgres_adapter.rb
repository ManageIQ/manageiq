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

        Benchmark.realtime_block(:write_multiple) do
          write_rows(interval_name, resource, start_time, end_time, data)

          data
        end
      end

      def transform_parameters(resource, interval_name, start_time, end_time, rt_rows)
        obj_perfs, = Benchmark.realtime_block(:db_find_prev_perfs) do
          # TODO(lsmola) store just attributes, not whole AR objects here
          Metric::Finders.hash_by_capture_interval_name_and_timestamp(resource, start_time, end_time, interval_name)
        end

        rt_rows.each do |ts, rt|
          if (perf = obj_perfs.fetch_path(interval_name, ts))
            rt.reverse_merge!(perf.attributes.symbolize_keys)
            rt.delete(:id) # Remove protected attributes
          end

          rt.merge!(Metric::Processing.process_derived_columns(resource, rt, interval_name == 'realtime' ? Metric::Helper.nearest_hourly_timestamp(ts) : nil))
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
          Benchmark.realtime_block(:process_perfs) do
            v[:resource_id] = resource.id
            v[:resource_type] = resource.class.base_class.name
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
