class ApplicationHelper::Button::ContainerTimeline < ApplicationHelper::Button::Container
  needs :@record

  def disabled?
    @error_message = _('No Timeline data has been collected for this %{entity}') %
                     {:entity => @entity} unless proper_events?
    @error_message.present?
  end

  private

  def proper_events?
    @record.has_events? || @record.has_events?(:policy_events)
  end
end
