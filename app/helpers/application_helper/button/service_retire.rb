class ApplicationHelper::Button::ServiceRetire < ApplicationHelper::Button::Basic
  needs :@record

  def disabled?
    @error_message = _('Service is already retired') if @record.retired
    @error_message.present?
  end
end
