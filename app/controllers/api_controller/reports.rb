class ApiController
  module Reports
    SCHEDULE_ATTR = %w(start_date interval time_zone send_email)
    #
    # Reports Supporting Methods
    #
    def results_query_resource(object)
      object.miq_report_results
    end

    def show_reports
      if @req.subcollection == "results" && (@req.s_id || expand?(:resources)) && attribute_selection == "all"
        @additional_attributes = %w(result_set)
      end
      show_generic
    end

    def show_results
      @additional_attributes = %w(result_set)
      show_generic
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

    def schedule_resource_reports(_type, id, data)
      schedule_data = fetch_schedule_data data
      MiqReport.find(id).add_schedule schedule_data
    end

    private

    def fetch_schedule_data(data)
      data['userid'] = @auth_user_obj.userid
      data['run_at'] = {
        :start_time => data['start_date'],
        :tz         => data['time_zone'],
        :interval   => {
          :unit  =>  data['interval']['unit'],
          :value =>  data['interval']['value']
        }
      }

      email_url_prefix = url_for( :controller => "report",
                                  :action => "show_saved") + "/"
      data['send_email'] ||= false

      schedule_options = {
        :send_email       => data['send_email'],
        :email_url_prefix => email_url_prefix,
        :miq_group_id     => @auth_user_obj.current_group_id
      }
      data['sched_action'] = { :method => "run_report",
                               :options => schedule_options }

      data.except(*SCHEDULE_ATTR)
    end
  end
end
