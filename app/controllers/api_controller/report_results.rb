class ApiController
  module ReportResults
    #
    # Report Results Supporting Methods
    #
    def results_query_resource(object)
      object.send("miq_report_results")
    end

    def show_reports
      if @req[:subcollection] == "results" && (@req[:s_id] || expand?(:resources)) && attribute_selection == "all"
        @req[:additional_attributes] = %w(result_set)
      end
      show_generic(:reports)
    end
  end
end
