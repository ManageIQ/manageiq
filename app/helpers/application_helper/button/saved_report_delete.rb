class ApplicationHelper::Button::SavedReportDelete < ApplicationHelper::Button::Basic
  include ApplicationHelper::Button::Mixins::XActiveTreeMixin

  def visible?
    reports_tree? ? saved_report? : true
  end

  private

  def saved_report?
    @view_context.active_tab == 'saved_reports'
  end
end
