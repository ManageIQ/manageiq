module Api
  module Subcollections
    module AlertStatusStates
      def alert_status_states_query_resource(object)
        object.miq_alert_status_states
      end

      def alert_status_states_add_resource(object, _type, _id, data = nil)
        alert_status_state = create_alert_status_state(data)
        object.miq_alert_status_states << alert_status_state
        alert_status_state
      end

      def alert_status_states_delete_resource(object, _type, id = nil, _data = nil)
        raise BadRequestError, "Must specify an id for deleting a #{type} resource" unless id
        alert_status_state = find_alert_status_state(object, id)
        delete_alert_status_state(alert_status_state)
      end

      def alert_status_states_edit_resource(object, _type, id = nil, data = nil)
        raise BadRequestError, "Must specify an id for editing a #{type} resource" unless id
        alert_status_state = find_alert_status_state(object, id)
        update_alert_status_state(alert_status_state, data)
        alert_status_state
      end

      def find_alert_status_state(object, id)
        object.miq_alert_status_states.find(id)
      rescue => err
        raise BadRequestError, err.to_s
      end

      def delete_alert_status_state(alert_status_state)
        return if alert_status_state.blank?
        alert_status_state.delete
      end

      def create_alert_status_state(data)
        MiqAlertStatusState.create(data)
      rescue => err
        raise BadRequestError, err.to_s
      end

      def update_alert_status_state(alert_status_state, data)
        alert_status_state.update_attributes!(data)
      rescue => err
        raise BadRequestError, err.to_s
      end
    end
  end
end
