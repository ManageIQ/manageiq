class ApplicationHelper::Button::GenericFeatureButton < ApplicationHelper::Button::Basic
  needs :@record

  def initialize(view_context, view_binding, instance_data, props)
    super
    @feature = props[:options][:feature]
  end

  def visible?
    begin
      return @record.send("supports_#{@feature}?")
    rescue NoMethodError # TODO: remove with deleting AvailabilityMixin module
      return @record.is_available?(@feature)
    end
  end
end
