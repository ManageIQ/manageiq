class ApplicationHelper::Button::ChargebackDownloadChoice < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if @view_context.x_active_tree == :cb_reports_tree &&
       @report && !@report.contains_records?
      self[:enabled] = false
      self[:title] = _("No records found for this report")
    end
  end
end
