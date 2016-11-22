module Api
  module Subcollections
    module AlertStatuses
      include Subcollections::AlertStatusStates

      def alert_statuses_query_resource(object)
        payload = {}
        payload = {"environment" => "production"}.merge("alerts" => alerts_and_states(object)) if object.respond_to?(:miq_alert_statuses)
        [payload]
      end

      private

      def alerts_and_states(provider)
        provider.miq_alert_statuses.collect do |alert_status|
          alert_status.alert_status_and_states
        end
      end
    end
  end
end
