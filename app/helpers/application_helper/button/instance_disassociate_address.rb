class ApplicationHelper::Button::InstanceDisassociateAddress < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @record.is_available_now_error_message(:disassociate_address) if disabled?
  end

  def disabled?
    !@record.is_available?(:disassociate_address)
  end
end
