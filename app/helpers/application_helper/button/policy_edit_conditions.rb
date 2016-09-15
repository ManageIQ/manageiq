class ApplicationHelper::Button::PolicyEditConditions < ApplicationHelper::Button::PolicyEdit

  def role_allows_feature?
    return true if super
    role_allows?(:feature => "policy_edit_conditions")
  end
end
