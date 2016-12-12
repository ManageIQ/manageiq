class ApplicationHelper::Button::VmRetireNow < ApplicationHelper::Button::Basic
  needs :@record

  def visible?
    @record.supports_retire?
  end

  def disabled?
    @error_message = _('VM is already retired') if @record.retired
    @error_message.present?
  end
end
