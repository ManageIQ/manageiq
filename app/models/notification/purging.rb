class Notification
  module Purging
    extend ActiveSupport::Concern
    include PurgingMixin

    module ClassMethods
      def purge_date
        nil
      end

      def purge_window_size
        ::Settings.notifications.history.purge_window_size
      end

      # Collects the notifications that have expired based on the expires_in
      # value for each notification type.  The "older_than" value is not used
      # for this function, so it is named as `_`.
      def purge_scope(_)
        Notification.joins(:notification_type)
                    .where("notifications.created_at + notification_types.expires_in * INTERVAL '1 second' < now()")
      end

      def purge_associated_records(ids)
        NotificationRecipient.where(:notification_id => ids).delete_all
      end
    end
  end
end
