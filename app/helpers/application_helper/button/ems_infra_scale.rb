class ApplicationHelper::Button::EmsInfraScale < ApplicationHelper::Button::Basic
  def role_allows_feature?
    super && role_allows?(:feature => "ems_infra_scale")
  end

  def visible?
    @record.class == ManageIQ::Providers::Openstack::InfraManager && @record.orchestration_stacks.count != 0
  end
end
