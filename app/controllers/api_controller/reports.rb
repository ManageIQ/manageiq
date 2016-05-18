class ApiController
  module Reports
    #
    # Reports Supporting Methods
    #
    def results_query_resource(object)
      object.miq_report_results
    end

    def show_reports
      if @req[:subcollection] == "results" && (@req[:s_id] || expand?(:resources)) && attribute_selection == "all"
        @req[:additional_attributes] = %w(result_set)
      end
      show_generic(:reports)
    end

    def show_results
      @req[:additional_attributes] = %w(result_set)
      show_generic(:results)
    end

    def run_resource_reports(_type, id, _data)
      report = MiqReport.find(id)
      report_result = MiqReportResult.find(report.queue_generate_table)
      run_report_result(true,
                        "running report #{report.id}",
                        :task_id          => report_result.miq_task_id,
                        :report_result_id => report_result.id)
    rescue => err
      run_report_result(false, err.to_s)
    end

    def run_report_result(success, message = nil, options = {})
      res = {:success => success}
      res[:message] = message if message.present?
      add_parent_href_to_result(res)
      add_report_result_to_result(res, options[:report_result_id]) if options[:report_result_id].present?
      add_task_to_result(res, options[:task_id]) if options[:task_id].present?
      res
    end

    def import_resource_reports(_type, _id, data)
      options = data.fetch("options", {}).symbolize_keys.merge(:user => @auth_user_obj)
      result, meta = MiqReport.import_from_hash(data["report"], options)
      action_result(meta[:level] == :info, meta[:message], :result => result)
    end
  end
end
