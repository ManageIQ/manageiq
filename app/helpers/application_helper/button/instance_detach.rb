class ApplicationHelper::Button::InstanceDetach < ApplicationHelper::Button::Basic
  def disabled?
    if @record.number_of(:cloud_volumes) == 0
      @error_message = _("%{model} \"%{name}\" has no attached %{volumes}") % {
        :model   => ui_lookup(:table => 'vm_cloud'),
        :name    => @record.name,
        :volumes => ui_lookup(:tables => 'cloud_volumes')
      }
    end
    @error_message.present?
  end
end
