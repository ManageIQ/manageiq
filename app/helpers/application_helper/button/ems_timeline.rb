class ApplicationHelper::Button::EmsTimeline < ApplicationHelper::Button::Basic
  def skip?
    !@record.is_available?(:timeline)
  end

  def disabled?
    !(@record.has_events? || @record.has_events?(:policy_events))
  end

  def calculate_properties
    super
    self[:hidden] = true if skip?
    self[:title] = N_("No Timeline data has been collected for this Provider") if disabled?
  end
end
