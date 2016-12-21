class ApplicationHelper::Button::VmTimeline < ApplicationHelper::Button::Basic
  needs :@record

  def disabled?
    @error_message = _('No Timeline data has been collected for this VM') unless proper_events?
  end

  private

  def proper_events?
    @record.has_events? || @record.has_events?(:policy_events)
  end
end
