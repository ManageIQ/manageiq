class ApplicationHelper::Button::Basic < Hash
  def initialize(view_context, view_binding, instance_data, props)
    @view_context  = view_context
    @view_binding  = view_binding

    merge!(props)

    instance_data.each do |name, value|
      instance_variable_set(:"@#{name}", value)
    end
  end

  def calculate_properties
    self[:enabled] = !disabled?
  end

  def skip?
    false
  end

  def disabled?
    false
  end
end
