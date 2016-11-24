class ApplicationHelper::Button::Reload < ApplicationHelper::Button::Basic
  include ApplicationHelper::Button::Mixins::XActiveTreeMixin

  def visible?
    return saved_report? if reports_tree?
    return root? if savedreports_tree?
    true
  end

  private

  def saved_report?
    @view_context.active_tab == 'saved_reports'
  end

  def root?
    @view_context.x_node == 'root'
  end
end
