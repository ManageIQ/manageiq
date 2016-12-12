class ApplicationHelper::Button::ChargebackReportOnly < ApplicationHelper::Button::Basic
  def disabled?
    @error_message = _('No records found for this report') if @view_context.x_active_tree == :cb_reports_tree &&
                                                              @report && !@report.contains_records?
    @error_message.present?
  end
end
