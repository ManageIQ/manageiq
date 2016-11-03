class ApplicationHelper::Button::OrchestrationTemplateMakeOrderable < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = _("This Template is already orderable") if disabled?
  end

  def disabled?
    @record.orchestration_template.orderable?
  end
end
