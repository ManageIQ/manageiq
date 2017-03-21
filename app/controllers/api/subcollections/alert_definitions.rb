module Api
  module Subcollections
    module AlertDefinitions
      def alert_definitions_query_resource(object)
        return {} unless object.respond_to?(:miq_alerts)
        object.miq_alerts
      end
    end
  end
end
