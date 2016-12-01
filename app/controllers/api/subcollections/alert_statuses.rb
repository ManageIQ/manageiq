module Api
  module Subcollections
    module AlertStatuses
      include Subcollections::AlertStatusStates

      def alert_statuses_query_resource(object)
        payload = {"alerts" => provider.miq_alert_statuses.collect(&:alert_status_and_states)} if object.respond_to?(:miq_alert_statuses)
        [payload]
      end
    end
  end
end
