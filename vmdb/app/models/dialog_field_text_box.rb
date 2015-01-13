class DialogFieldTextBox < DialogField
  has_one :resource_action, :as => :resource, :dependent => :destroy

  after_initialize :default_resource_action

  def refresh_button_pressed
    self.default_value = nil
    values
  end

  def update_values(passed_in_values)
    @values = passed_in_values
  end

  def values
    if dynamic
      @values = values_from_automate
    else
      @values
    end
  end

  def initial_values
    "<None>"
  end

  def protected=(passed_in_value)
    self.options[:protected] = passed_in_value
  end

  def protected?
    self.options[:protected] == true
  end

  def value_from_dialog_fields(dialog_values)
    value_from_dialog_field = dialog_values[automate_key_name]
    self.protected? ? MiqPassword.decrypt(value_from_dialog_field) : value_from_dialog_field
  end

  def automate_output_value
    return MiqPassword.encrypt(value) if self.protected?
    value
  end

  def automate_key_name
    return "password::#{super}" if self.protected?
    super
  end

  def validate(dialog_tab, dialog_group)
    case validator_type
    when 'regex'
      return "#{dialog_tab.label}/#{dialog_group.label}/#{label} is invalid" unless value.match(/#{validator_rule}/)
    end
    super
  end

  def script_error_values
    "<Script error>"
  end

  def normalize_automate_values(passed_in_values)
    return initial_values if passed_in_values.blank?
    passed_in_values.to_s
  end

  private

  def default_resource_action
    build_resource_action if resource_action.nil?
  end

  def values_from_automate
    DynamicDialogFieldValueProcessor.values_from_automate(self)
  end
end
