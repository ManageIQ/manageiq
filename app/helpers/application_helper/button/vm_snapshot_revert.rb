class ApplicationHelper::Button::VmSnapshotRevert < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    return false if @record.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Vm)
    super
  end
end
