class ApplicationHelper::Button::GenericFeatureButton < ApplicationHelper::Button::Basic
  needs_record

  def initialize(view_context, view_binding, instance_data, props)
    super(view_context, view_binding, instance_data, props)
    @feature = props[:options][:feature]
  end

  def skip?
    ret = @record.try("supports_#{@feature}?")
    ret = @record.try(:is_available?, @feature) if ret.nil? # TODO: remove with deleting AvailabilityMixin module
    !ret
  end
end
