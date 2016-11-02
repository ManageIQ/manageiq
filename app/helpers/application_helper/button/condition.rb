class ApplicationHelper::Button::Condition < ApplicationHelper::Button::ReadOnly
  needs :@sb, :@condition

  def role_allows_feature?
    @view_context.x_active_tree == :condition_tree && role_allows?(:feature => self[:child_id])
  end

  def calculate_properties
    super
    self[:title] = @error_message if disabled?
  end

  def disabled?
    if !@condition.miq_policies.empty? && self[:child_id].include?("delete")
      @error_message = N_("Conditions assigned to Policies can not be deleted")
    end
    @error_message.present?
  end
end
