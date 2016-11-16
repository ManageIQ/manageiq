class ApplicationHelper::Button::OrchestrationTemplateViewInCatalog < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = _("This Template is not orderable") unless @record.orchestration_template.orderable?
  end

  def disabled?
    !@record.orchestration_template.orderable?
  end
end
