class ApplicationHelper::Button::OrchestrationTemplateCopyOrderable < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = N_("This Template is already orderable") if disabled?
  end

  def disabled?
    @record.orchestration_template.orderable?
  end
end
