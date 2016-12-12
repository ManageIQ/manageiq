class ApplicationHelper::Button::InstanceAttach < ApplicationHelper::Button::Basic
  def disabled?
    if @record.cloud_tenant.cloud_volumes.where(:status => 'available').count.zero?
      @error_message = _("There are no %{volumes} available to attach to this %{model}.") % {
        :volumes => ui_lookup(:tables => 'cloud_volumes'),
        :model   => ui_lookup(:table => 'vm_cloud')
      }
    end
    @error_message.present?
  end
end
