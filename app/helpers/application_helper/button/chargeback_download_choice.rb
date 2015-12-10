class ApplicationHelper::Button::ChargebackDownloadChoice < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if @view_context.x_active_tree == :cb_reports_tree &&
       @report && !@report.contains_records?
      props["enabled"] = "false"
      props["title"] = _("No records found for this report")
    end
  end
end
