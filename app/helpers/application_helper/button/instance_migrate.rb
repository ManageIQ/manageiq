class ApplicationHelper::Button::InstanceMigrate < ApplicationHelper::Button::Basic
  def disabled?
    @error_message = @record.unsupported_reason(:live_migrate) unless @record.supports_live_migrate?
    @error_message.present?
  end
end
