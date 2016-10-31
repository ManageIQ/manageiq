class EventStream < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern

    module ClassMethods
      def keep_ems_events
        VMDB::Config.new("vmdb").config.fetch_path(:ems_events, :history, :keep_ems_events)
      end

      def purge_date
        keep = keep_ems_events.to_i_with_method.seconds
        keep = 6.months if keep == 0
        keep.ago.utc
      end

      def purge_window_size
        VMDB::Config.new("vmdb").config.fetch_path(:ems_events, :history, :purge_window_size) || 1000
      end

      def purge_timer
        purge_queue(purge_date)
      end

      def purge_queue(ts)
        MiqQueue.put(
          :class_name  => name,
          :method_name => "purge",
          :role        => "event",
          :queue_name  => "ems",
          :args        => [ts],
        )
      end

      def purge(older_than, window = nil, limit = nil)
        _log.info("Purging #{limit || "all"} events older than [#{older_than}]...")

        window ||= purge_window_size

        total = where(arel_table[:timestamp].lteq(older_than)).delete_in_batches(window, limit) do |count, _total|
          _log.info("Purging #{count} events.")
        end

        _log.info("Purging #{limit || "all"} events older than [#{older_than}]...Complete - Deleted #{total} records")
      end
    end
  end
end
