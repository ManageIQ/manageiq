class ApplicationHelper::Button::RefreshWorkers < ApplicationHelper::Button::Basic
  needs :@record, :@sb

  def visible?
    @view_context.x_active_tree == :diagnostics_tree && @sb[:active_tab] == 'diagnostics_workers'
  end
end
