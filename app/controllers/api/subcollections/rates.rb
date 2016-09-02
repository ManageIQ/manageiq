module Api
  module Subcollections
    module Rates
      def rates_query_resource(object)
        object.chargeback_rate_details
      end
    end
  end
end
