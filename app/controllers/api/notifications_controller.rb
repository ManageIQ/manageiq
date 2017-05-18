module Api
  class NotificationsController < BaseController
    def notifications_search_conditions
      {:user_id => User.current_user.id}
    end

    def find_notifications(id)
      User.current_user.notification_recipients.find(id)
    end

    def mark_as_seen_resource(type, id = nil, _data = nil)
      api_action(type, id) do |klass|
        notification = resource_search(id, type, klass)
        action_result(notification.update_attribute(:seen, true) || false)
      end
    end
  end
end
