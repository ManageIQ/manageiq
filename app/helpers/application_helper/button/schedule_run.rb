class ApplicationHelper::Button::ScheduleRun < ApplicationHelper::Button::Basic
  def visible?
    @view_context.x_active_tree != :settings_tree
  end
end
