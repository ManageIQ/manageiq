class ApplicationHelper::Button::VolumeAttach < ApplicationHelper::Button::Basic
  def disabled?
    @error_message = @record.is_available_now_error_message(:attach_volume) unless @record.is_available?(:attach_volume)
    @error_message.present?
  end
end
