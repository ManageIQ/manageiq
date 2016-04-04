class ApplicationHelper::Button::ReportDownloadChoice < ApplicationHelper::Button::Basic
  def disabled?
    MiqReportResult.find(@report_result_id).try(:miq_report_result_details).try(:length).to_i == 0
  end
end
