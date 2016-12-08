class ApplicationHelper::Button::OrchestrationTemplateMakeOrderable < ApplicationHelper::Button::Basic
  def disabled?
    @error_message = _('This Template is already orderable') if @record.orchestration_template.orderable?
    @error_message.present?
  end
end
