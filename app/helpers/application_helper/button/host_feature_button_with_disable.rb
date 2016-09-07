class ApplicationHelper::Button::HostFeatureButtonWithDisable < ApplicationHelper::Button::GenericFeatureButtonWithDisable
  needs_record

  def visible?
    return false if @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager)
    super
  end
end
