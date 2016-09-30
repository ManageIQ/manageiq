class ApplicationHelper::Button::VmRetireNow < ApplicationHelper::Button::Basic
  needs :@record

  def calculate_properties
    super
    self[:title] = N_("VM is already retired") if disabled?
  end

  def visible?
    @record.supports_retire?
  end

  def disabled?
    @record.retired
  end
end
