class ApplicationHelper::Button::HostIntrospectProvide < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    proper_record? && host_manageable?
  end

  private

  def proper_record?
    @record.class == ManageIQ::Providers::Openstack::InfraManager::Host
  end

  def host_manageable?
    @record.hardware.provision_state == "manageable"
  end
end
