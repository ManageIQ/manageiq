class ApiController
  module Reports

    def run_report()
      report_type = MiqReport.find(@req[:c_id])
      rr_id = report_type.queue_generate_table(:userid => session[:userid])
      render json: {:report_result_id => rr_id}
    end

    # Returns the latest report of type with ID <report_type_id>.
    #
    # /api/reports/<report_type_id>
    #
    def get_report()
      if params[:report_result_id]
        rr_id = params[:report_result_id]
        result_report = MiqReportResult.find_by_id(rr_id)
      else  
        result_report = MiqReportResult.where(
          'miq_report_id = :id', :id => @req[:c_id]
        ).order('last_run_on').last
      end

      if result_report.nil?
        raise BadRequestError, "No reports were found.  " +
          "If you want to run a report, make a POST call instead. "
      end

      disable_client_cache
      filename = result_report.report.title + "_" + format_timezone(Time.now, Time.zone, "fname")
      send_data(result_report.report_results.to_csv,
                :filename => "#{filename}.csv",
                :type     => "application/csv")
      return
    end

    def show_reports()
      check_collection_id_exists
      get_report
    end

    def update_reports()
      check_collection_id_exists
      run_report
    end

    def check_collection_id_exists
      if @req[:c_id].nil?
        raise BadRequestError, "missing report type ID"
      end
    end
  end
end
