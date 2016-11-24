class ApplicationHelper::Button::MiqReportAction < ApplicationHelper::Button::Basic
  def visible?
    @view_context.active_tab != 'saved_reports'
  end
end
