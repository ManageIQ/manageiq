class ApplicationHelper::Button::OrchestrationTemplateEditRemove < ApplicationHelper::Button::Basic
  needs :@record

  def disabled?
    if @record.in_use?
      @error_message = if self[:id] =~ /_edit$/
                         _('Orchestration Templates that are in use cannot be edited')
                       else
                         _('Orchestration Templates that are in use cannot be removed')
                       end
    end
    @error_message.present?
  end
end
