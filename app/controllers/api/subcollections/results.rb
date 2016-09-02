module Api
  module Subcollections
    module Results
      def results_query_resource(object)
        object.miq_report_results
      end
    end
  end
end
