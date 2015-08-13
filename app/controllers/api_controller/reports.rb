class ApiController
  module Reports
    #
    # Reports Supporting Methods
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

    def run_resource_reports(_type, id, _data)
      report = MiqReport.find(id)
      result_id = report.queue_generate_table
      MiqReportResult.find(result_id)
    end
  end
end
