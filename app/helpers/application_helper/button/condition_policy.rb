class ApplicationHelper::Button::ConditionPolicy < ApplicationHelper::Button::ReadOnly
  needs :@sb

  def role_allows_feature?
    @view_context.x_active_tree != :condition_tree && role_allows?(:feature => self[:child_id])
  end
end
