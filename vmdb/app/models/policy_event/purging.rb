class PolicyEvent < ActiveRecord::Base
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_date
        (purge_config(:keep_policy_events) || 6.months).to_i_with_method.ago.utc
      end

      def purge_window_size
        purge_config(:purge_window_size) || 1000
      end

      def purge_queue
        MiqQueue.put_unless_exists(
          :class_name  => name,
          :method_name => "purge",
          :role        => "event",
          :queue_name  => "ems"
        )
      end
      alias_method :purge_timer, :purge_queue

      def purge_conditions(older_than)
        where(arel_table[:timestamp].lt(older_than))
      end

      def purge_associated_records(ids)
        PolicyEventContent.delete_all(:policy_event_id => ids)
      end

      private

      def purge_config(key)
        VMDB::Config.new("vmdb").config.fetch_path(:policy_events, :history, key)
      end
    end
  end
end
