class ApplicationHelper::Button::HostFeatureButton < ApplicationHelper::Button::GenericFeatureButton
  needs_record

  def visible?
    return false if @record.kind_of?(ManageIQ::Providers::Openstack::InfraManager)
    super
  end
end
