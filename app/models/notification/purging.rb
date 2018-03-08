class Notification
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_date
        ::Settings.notifications.history.keep_notifications.to_i_with_method.seconds.ago.utc
      end

      def purge_window_size
        ::Settings.notifications.history.purge_window_size
      end

      def purge_scope(older_than)
        where(arel_table[:created_at].lt(older_than))
      end

      def purge_associated_records(ids)
        NotificationRecipient.where(:notification_id => ids).delete_all
      end
    end
  end
end
