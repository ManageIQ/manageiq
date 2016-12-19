module Api
  module Subcollections
    module Alerts
      def alerts_query_resource(object)
        object.try(:miq_alert_statuses) || []
      end
    end
  end
end
