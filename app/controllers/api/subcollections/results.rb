module Api
  module Subcollections
    module Results
      def find_results(id)
        MiqReportResult.for_user(@auth_user_obj).find(id)
      end

      def results_query_resource(object)
        object.miq_report_results.for_user(@auth_user_obj)
      end
    end
  end
end
