class ApplicationHelper::Button::GenericFeatureButton < ApplicationHelper::Button::Basic
  needs_record

  def initialize(view_context, view_binding, instance_data, props)
    super(view_context, view_binding, instance_data, props)
    @feature = props[:options][:feature]
  end

  def skip?
    begin
      return !@record.send("supports_#{@feature}?")
    rescue NoMethodError # TODO: remove with deleting AvailabilityMixin module
      return !@record.is_available?(@feature)
    end
  end
end
