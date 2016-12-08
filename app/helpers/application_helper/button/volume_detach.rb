class ApplicationHelper::Button::VolumeDetach < ApplicationHelper::Button::Basic
  def disabled?
    if !@record.is_available?(:detach_volume)
      @error_message = @record.is_available_now_error_message(:detach_volume)
    elsif @record.number_of(:vms) == 0
      @error_message = _("%{model} \"%{name}\" is not attached to any %{instances}") % {
        :model     => ui_lookup(:table => 'cloud_volume'),
        :name      => @record.name,
        :instances => ui_lookup(:tables => 'vm_cloud')
      }
    end
    @error_message.present?
  end
end
