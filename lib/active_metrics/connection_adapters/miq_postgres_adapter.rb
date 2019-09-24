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
        resources, interval_name, start_time, end_time, data = params.first
        write_rows(resources, interval_name, start_time, end_time, data)
        data
      end

      private

      def write_rows(resources, interval_name, start_time, end_time, data)
        klass, meth = Metric::Helper.class_and_association_for_interval_name(interval_name)

        samples_arel = klass.where(:capture_interval_name => interval_name).where(:resource => resources).where(:timestamp => start_time..end_time)

        samples_inventory_collection = ::InventoryRefresh::InventoryCollection.new(
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
          # TODO(lsmola) where can I can take the manager from?
          InventoryRefresh::SaveInventory.save_inventory(resources.first.ext_management_system, [samples_inventory_collection])
        end
        created_count = samples_inventory_collection.created_records.count
        updated_count = samples_inventory_collection.updated_records.count
        # Assign nil so GC can clean it up
        samples_inventory_collection = nil

        if interval_name == 'hourly'
          _log.info("#{log_header} Adding missing timestamp intervals...")
          resources.each do |resource|
            Benchmark.realtime_block(:add_missing_intervals) { Metric::Processing.add_missing_intervals(resource, "hourly", start_time, end_time) }
          end
          _log.info("#{log_header} Adding missing timestamp intervals...Complete")
        end

        _log.info("#{log_header} Processing #{data.length} performance rows...Complete - Added #{created_count} / Updated #{updated_count}")
      end
    end
  end
end
