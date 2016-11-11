class ApplicationHelper::Button::TenantAdd < ApplicationHelper::Button::GenericFeatureButton
  needs :@record
  delegate :role_allows?, :rbac_common_feature_for_buttons, :to => :@view_context

  def role_allows_feature?
    return role_allows?(:feature => rbac_common_feature_for_buttons(self[:child_id]))
  end

  def visible?
    true
  end
end
