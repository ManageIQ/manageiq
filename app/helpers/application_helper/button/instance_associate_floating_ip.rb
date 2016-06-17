class ApplicationHelper::Button::InstanceAssociateFloatingIp < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @record.is_available_now_error_message(:associate_floating_ip) if disabled?
  end

  def disabled?
    !@record.is_available?(:associate_floating_ip)
  end
end
