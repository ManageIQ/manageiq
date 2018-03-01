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
      #
      # First, this collects all of the notification_types and groups them by
      # expires_in value (we only seed 3 different types currently).
      #
      # It then builds a single query that matches against each
      # notification_type and if it has expired that specific expires_in for
      # that type.
      def purge_scope(_)
        query = nil

        # Make a query to collect the expires_in and id columns for all of the
        # NotificationTypes, and then put them into a hash with the key being
        # the expires_in column, and the values being all of the ids matching
        # the expires_in value.
        expire_ids = NotificationType.pluck(:expires_in, :id)
        expire_ids = expire_ids.each_with_object({}) do |(key, id), result|
          result[key] ||= []
          result[key] << id
        end

        # Create a query that matches on the notification on expires_in for
        # specific ids that have that exact same expires_in time. So something
        # like:
        #
        #   SELECT *
        #   FROM "notifications"
        #   WHERE ((("notifications"."notification_type_id" IN (1,2,3)
        #          AND "notifications"."created_at" < [[1.days.ago.utc]])
        #      OR ("notifications"."notification_type_id" IN (4,5,6)
        #          AND "notifications"."created_at" < [[7.days.ago.utc]]))
        #      OR ("notifications"."notification_type_id" IN (7,8,9)
        #          AND "notifications"."created_at" < [[14.days.ago.utc]]))
        #
        expire_ids.each do |expires_in, type_ids|
          new_condition = arel_table.grouping(
            arel_table[:notification_type_id].in(type_ids).and(
              arel_table[:created_at].lt(expires_in.seconds.ago.utc)
            )
          )
          query = query.nil? ? new_condition : query.or(new_condition)
        end

        where(query)
      end

      def purge_associated_records(ids)
        NotificationRecipient.where(:notification_id => ids).delete_all
      end
    end
  end
end
