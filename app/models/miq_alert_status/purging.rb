class MiqAlertStatus < ApplicationRecord
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_date
        ::Settings.miq_alert_status.history.keep_miq_alert_statuses.to_i_with_method.seconds.ago.utc
      end

      def purge_window_size
        ::Settings.miq_alert_status.history.purge_window_size
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

      def purge_scope(older_than)
        # TODO: should happen only when ems no longer exists
        where(arel_table[:timestamp].lt(older_than))
      end

      def purge_associated_records(ids)

      end
    end
  end
end
