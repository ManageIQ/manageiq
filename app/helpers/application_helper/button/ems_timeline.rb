class ApplicationHelper::Button::EmsTimeline < ApplicationHelper::Button::Basic
  def visible?
    @record.supports_timeline?
  end

  def disabled?
    !(@record.has_events? || @record.has_events?(:policy_events))
  end

  def calculate_properties
    super
    self[:hidden] = true unless visible?
    self[:title] = N_("No Timeline data has been collected for this Provider") if disabled?
  end
end
