class ApplicationHelper::Button::OrchestrationTemplateEditRemove < ApplicationHelper::Button::Basic
  needs :@record

  def disabled?
    @record.in_use?
  end

  def calculate_properties
    super
    if disabled?
      self[:title] = if self[:id] =~ /_edit$/
                       _('Orchestration Templates that are in use cannot be edited')
                     else
                       _('Orchestration Templates that are in use cannot be removed')
                     end
    end
  end
end
