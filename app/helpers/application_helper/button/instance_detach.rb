class ApplicationHelper::Button::InstanceDetach < ApplicationHelper::Button::Basic
  def disabled?
    if @record.number_of(:cloud_volumes).zero?
      @error_message = _("This %{model} has no attached %{volumes}.") % {
        :model   => ui_lookup(:table => 'vm_cloud'),
        :name    => @record.name,
        :volumes => ui_lookup(:tables => 'cloud_volumes')
      }
    end
    @error_message.present?
  end
end
