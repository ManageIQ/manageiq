class ApplicationHelper::Button::InstanceEvacuate < ApplicationHelper::Button::Basic
  def calculate_properties
    super
    self[:title] = @record.unsupported_reason(:evacuate) if disabled?
  end

  def disabled?
    !@record.supports_evacuate?
  end
end
