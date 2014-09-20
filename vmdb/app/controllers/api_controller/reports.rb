class ApiController
  module Reports

    # queue up a new report request given a report type ID
    def run_report()
      report_type = MiqReport.find(json_body["report_type_id"])
      if report_type.nil?
        raise BadRequestError, 
          "No report type with ID of '#{json_body["report_type_id"]}' exists." 
      end
      rr_id = report_type.queue_generate_table(:userid => session[:userid])
      render json: {
        :href => "#{@req[:url]}#{rr_id}",
        :id => rr_id
      }
    end
    
    # return a report as a CSV
    def to_csv(result_report)
      disable_client_cache
      filename = result_report.report.title + 
        "_" + 
        format_timezone(Time.now, Time.zone, "fname")
      send_data(result_report.report_results.to_csv,
                :filename => "#{filename}.csv",
                :type     => "application/csv")
    end

    # return a report by its ID
    def get_report()
      result_report = MiqReportResult.find_by_id(@req[:c_id])
      if result_report.nil?
        raise BadRequestError, "No report with that ID exists."
      end

      to_csv(result_report)
    end

    # return the latest report for a specific report type as a CSV
    def get_latest_report(type_id = nil)
      result_report = MiqReportResult.where(
        'miq_report_id = :id', :id => type_id 
      ).order('last_run_on').last

      if result_report.nil?
        render json: {
          :msg => "No reports with report type ID '#{type_id}' exist."
        }
        return
      end

      to_csv(result_report)
    end

    # get all available reports
    def get_all_reports()
      reports = []
      report_results = MiqReportResult.all()
      report_results.each do |rr|
        reports.append({
          :id => rr.id,
          :href => "#{@req[:url]}#{rr.id}",
          :report_type_id => rr.miq_report_id,
          :report_type_name => rr.name
        })
      end
      render json: {
        :total => reports.length(),
        :resources => reports
      }
      return
    end

    # return a report if a valid report ID is provided
    # otherwise rturn a list of all the reports
    def show_reports()
      if @req[:c_id]
        return get_report()
      end

      if params[:report_type_id]
        return get_latest_report(params[:report_type_id])
      end

      get_all_reports()
    end

    # run a report (named as 'update' to use the default API routing logic)
    def update_reports()
      if json_body["report_type_id"]
        return run_report()
      end
      raise BadRequestError, "Missing 'report_type_id' parameter."
    end
  end
end
