class ApplicationHelper::Button::VmSnapshotRevert < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    return false if @record.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Vm)
    super
  end

  def disabled?
    @error_message = if @active
                       _('Select a snapshot that is not the active one')
                     elsif !@record.is_available?(:revert_to_snapshot)
                       @record.is_available_now_error_message(:revert_to_snapshot)
                     end
    @error_message.present?
  end
end
