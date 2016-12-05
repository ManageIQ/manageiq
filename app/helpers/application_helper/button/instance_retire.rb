class ApplicationHelper::Button::InstanceRetire < ApplicationHelper::Button::Basic
  needs :@record

  def disabled?
    @error_message = _('Instance is already retired') if @record.retired
    @error_message.present?
  end
end
