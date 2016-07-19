class ApplicationHelper::Button::VmRetire < ApplicationHelper::Button::Basic
  needs_record

  def calculate_properties
    self[:title] = N_("VM is already retired") if disabled?
  end

  def skip?
    !@record.supports_retire?
  end

  def disabled?
    @record.retired
  end
end
