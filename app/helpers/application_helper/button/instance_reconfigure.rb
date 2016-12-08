class ApplicationHelper::Button::InstanceReconfigure < ApplicationHelper::Button::Basic
  def disabled?
    @error_message = @record.unsupported_reason(:resize) unless @record.supports_resize?
    @error_message.present?
  end
end
