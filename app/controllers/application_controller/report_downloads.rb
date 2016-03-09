module ApplicationController::ReportDownloads
  extend ActiveSupport::Concern

  # Send the current report in text format
  def render_txt
    @report = report_for_rendering
    filename = filename_timestamp(@report.title)
    disable_client_cache
    send_data(@report.to_text,
              :filename => "#{filename}.txt")
  end

  # Send the current report in csv format
  def render_csv
    @report = report_for_rendering
    filename = filename_timestamp(@report.title)
    disable_client_cache
    send_data(@report.to_csv,
              :filename => "#{filename}.csv")
  end

  # Send the current report in pdf format
  def render_pdf(report = nil)
    report ||= report_for_rendering
    if report
      userid = "#{session[:userid]}|#{request.session_options[:id]}|adhoc"
      rr = report.build_create_results(:userid => userid)
    end

    # Use rr frorm paging, if present
    rr ||= MiqReportResult.find(@sb[:pages][:rr_id]) if @sb[:pages]
    # Use report_result_id in session, if present
    rr ||= MiqReportResult.find(session[:report_result_id]) if session[:report_result_id]

    filename = filename_timestamp(rr.report.title)
    disable_client_cache
    send_data(rr.to_pdf, :filename => "#{filename}.pdf", :type => 'application/pdf')
  end

  private

  def report_for_rendering
    if session[:rpt_task_id]
      miq_task = MiqTask.find(session[:rpt_task_id])
      miq_task.task_results
    elsif session[:report_result_id]
      rr = MiqReportResult.find(session[:report_result_id])
      report = rr.report_results
      report.report_run_time = rr.last_run_on
      report
    end
  end

  def filename_timestamp(basename, format = 'fname')
    basename + '_' + format_timezone(Time.zone.now, Time.zone, format)
  end
end
