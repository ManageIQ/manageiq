class ApplicationHelper::Button::EmsInfraScale < ApplicationHelper::Button::Basic
  def visible?
    @record.class == ManageIQ::Providers::Openstack::InfraManager && @record.orchestration_stacks.count != 0
  end
end
