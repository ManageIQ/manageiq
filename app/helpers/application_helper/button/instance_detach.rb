class ApplicationHelper::Button::InstanceDetach < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if !@record.is_available?(:detach_volume)
      self[:title] = @record.is_available_now_error_message(:detach_volume)
    elsif @record.number_of(:cloud_volumes) == 0
      self[:title] = _("%{model} \"%{name}\" has no attached %{volumes}") % {
        :model   => ui_lookup(:table => 'vm_cloud'),
        :name    => @record.name,
        :volumes => ui_lookup(:tables => 'cloud_volumes')
      }
    end
  end

  def disabled?
    !@record.is_available?(:detach_volume) || @record.number_of(:cloud_volumes) == 0
  end
end
