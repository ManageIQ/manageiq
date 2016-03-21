class ApplicationHelper::Button::OrchestrationTemplateOrderable < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self["title"] = N_("This Template is already orderable") if @record.orchestration_template.orderable?
  end

  def disabled?
    @record.orchestration_template.orderable?
  end
end
