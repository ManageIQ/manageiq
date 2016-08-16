class ApplicationHelper::Button::Basic < Hash
  include ActionView::Helpers::TextHelper

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

  # Sets the attributes for the button:
  #   self[:enabled] -- displayed button is enabled
  #   self[:title]   -- button has the title on hover
  #   self[:prompt]  -- the user has to confirm the action
  #   self[:hidden]  -- the button is not displayed in the toolbar
  #   self[:text]    -- text for the button
  def calculate_properties
    self[:enabled] = !disabled? if self[:enabled].nil?
  end

  def skipped?
    return true if self.class.record_needed && @record.nil?
    calculate_properties
    skip?
  end

  # Tells whether the button should displayed in the toolbar or not:
  #   false => button will be displayed
  #   true => button will be hidden
  def skip?
    false
  end

  # Tells whether the displayed button should be disabled or not
  def disabled?
    false
  end


  class << self
    attr_reader :record_needed

    # Used to avoid rendering buttons dependent on `@record` instance variable
    # if the variable is not set
    def needs_record
      @record_needed = true
    end
  end
end
