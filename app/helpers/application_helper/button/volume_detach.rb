class ApplicationHelper::Button::InstanceDetach < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    if !@record.is_available?(:detach_volume)
      self[:title] = @record.is_available_now_error_message(:detach_volume)
    elsif @record.number_of(:attachments) == 0
      self[:title] = _("%{model} \"%{name}\" is not attached to any %{instances}") % {
        :model     => ui_lookup(:table => 'cloud_volume'),
        :name      => @record.name,
        :instances => ui_lookup(:tables => 'vm_cloud')
      }
    end
  end

  def disabled?
    !@record.is_available?(:detach_volume) || @record.number_of(:attachments) == 0
  end
end
