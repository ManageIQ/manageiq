class ApplicationHelper::Button::InstanceAttach < ApplicationHelper::Button::Basic
  def disabled?
    if @record.cloud_tenant.cloud_volumes.where(:status => 'available').count.zero?
      @error_message = _("There are no Cloud Volumes available to attach to this Instance.")
    end
    @error_message.present?
  end
end
