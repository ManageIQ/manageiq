class ApplicationHelper::Button::Basic < Hash
  def initialize(view_context, view_binding, instance_data, props)
    @view_context  = view_context
    @view_binding  = view_binding

    merge!(props)

    instance_data.each do |name, value|
      instance_variable_set(:"@#{name}", value)
    end
  end

  # Return content under key such as :text or :confirm run through gettext or
  # evalated in the context of controller variables and helper methods.
  def localized(key)
    case self[key]
    when NilClass then ''
    when Proc     then instance_eval(&self[key])
    else               _(self[key])
    end
  end

  def calculate_properties
    self[:enabled] = !disabled? if self[:enabled].nil?
  end

  def skip?
    false
  end

  def disabled?
    false
  end
end
