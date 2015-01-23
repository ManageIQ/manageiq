class DialogFieldTextBox < DialogField
  has_one :resource_action, :as => :resource, :dependent => :destroy

  after_initialize :default_resource_action

  def refresh_button_pressed
    default_value
  end

  def default_value
    write_attribute(:default_value, values_from_automate) if dynamic
    read_attribute(:default_value)
  end

  def initial_values
    "<None>"
  end

  def protected=(passed_in_value)
    options[:protected] = passed_in_value
  end

  def protected?
    options[:protected] == true
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

  def normalize_automate_values(automate_hash)
    %w(data_type default_value protected required validator_type validator_rule).each do |key|
      send("#{key}=", automate_hash[key]) if automate_hash.key?(key)
    end

    return initial_values if automate_hash["default_value"].blank?
    automate_hash["default_value"].to_s
  end

  private

  def default_resource_action
    build_resource_action if resource_action.nil?
  end

  def values_from_automate
    DynamicDialogFieldValueProcessor.values_from_automate(self)
  end
end
