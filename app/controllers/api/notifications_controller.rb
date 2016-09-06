module Api
  class NotificationsController < BaseController
    def notifications_search_conditions
      {:user_id => @auth_user_obj.id}
    end

    def find_notifications(id)
      @auth_user_obj.notification_recipients.find(id)
    end

    def mark_as_seen_resource(type, id = nil, _data = nil)
      api_action(type, id) do |klass|
        notification = resource_search(id, type, klass)
        action_result(notification.update_attribute(:seen, true) || false)
      end
    end
  end
end
