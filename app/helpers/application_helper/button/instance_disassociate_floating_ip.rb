class ApplicationHelper::Button::InstanceDisassociateFloatingIp < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @record.is_available_now_error_message(:disassociate_floating_ip) if disabled?
  end

  def disabled?
    !@record.is_available?(:disassociate_floating_ip)
  end
end
