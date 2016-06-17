class ApplicationHelper::Button::InstanceAssociateAddress < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @record.is_available_now_error_message(:associate_address) if disabled?
  end

  def disabled?
    !@record.is_available?(:associate_address)
  end
end
