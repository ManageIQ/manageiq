class ApplicationHelper::Button::EmsTimeline < ApplicationHelper::Button::Basic
  def visible?
    @record.is_available?(:timeline)
  end

  def disabled?
    !(@record.has_events? || @record.has_events?(:policy_events))
  end

  def calculate_properties
    super
    self[:hidden] = true unless visible?
    self[:title] = _("No Timeline data has been collected for this Provider") if disabled?
  end
end
