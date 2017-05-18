module Api
  module Subcollections
    module AlertActions
      def alert_actions_query_resource(object)
        object.miq_alert_status_actions
      end

      def alert_actions_create_resource(object, type, _id, data)
        attributes = data.dup
        attributes['miq_alert_status_id'] = object.id
        attributes['user_id'] = User.current_user.id
        if data.key?('assignee')
          attributes['assignee_id'] = parse_id(attributes.delete('assignee'), :users)
        end
        alert_action = collection_class(type).create(attributes)
        if alert_action.invalid?
          raise BadRequestError,
                "Failed to add a new alert action resource - #{alert_action.errors.full_messages.join(', ')}"
        end
        alert_action
      end
    end
  end
end
