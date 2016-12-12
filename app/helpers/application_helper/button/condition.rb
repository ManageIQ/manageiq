class ApplicationHelper::Button::Condition < ApplicationHelper::Button::ReadOnly
  needs :@sb, :@condition

  def role_allows_feature?
    @view_context.x_active_tree == :condition_tree && role_allows?(:feature => self[:child_id])
  end

  def disabled?
    @error_message = _('Conditions assigned to Policies can not be deleted') if !@condition.miq_policies.empty? &&
                                                                                self[:child_id].include?('delete')
    @error_message.present?
  end
end
