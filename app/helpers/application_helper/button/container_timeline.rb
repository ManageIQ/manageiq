class ApplicationHelper::Button::ContainerTimeline < ApplicationHelper::Button::Basic
  needs :@record

  def initialize(view_context, view_binding, instance_data, props)
    super
    @entity = props[:options][:entity]
  end

  def calculate_properties
    super
    self[:title] = @error_message if @error_message.present?
  end

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
