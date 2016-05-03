class DialogFieldTextBox < DialogField
  AUTOMATE_VALUE_FIELDS = %w(data_type protected required validator_rule validator_type read_only).freeze

  def value
    @value = values_from_automate if dynamic && @value.blank?
    return @value if @value.nil?
    data_type == "integer" ? @value.to_i : @value
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
    return MiqPassword.encrypt(@value) if self.protected?
    @value
  end

  def automate_key_name
    return "password::#{super}" if self.protected?
    super
  end

  def validate_field_data(dialog_tab, dialog_group)
    return if !required? && @value.blank?

    return "#{dialog_tab.label}/#{dialog_group.label}/#{label} is required" if required? && @value.blank?
    if data_type == "integer" && !@value.match(/^[0-9]+$/)
      return "#{dialog_tab.label}/#{dialog_group.label}/#{label} must be an integer"
    end

    # currently only regex is supported
    rule = validator_rule if validator_type == 'regex'

    return unless rule
    "#{dialog_tab.label}/#{dialog_group.label}/#{label} is invalid" unless value.match(/#{rule}/)
  end

  def script_error_values
    "<Script error>"
  end

  def sample_text
    dynamic ? "Sample Text" : (value || default_value)
  end

  def normalize_automate_values(automate_hash)
    self.class::AUTOMATE_VALUE_FIELDS.each do |key|
      send("#{key}=", automate_hash[key]) if automate_hash.key?(key)
    end

    automate_hash["value"].to_s.presence || initial_values
  end

  def refresh_json_value
    @value = values_from_automate

    {:text => @value}
  end

  def trigger_automate_value_updates
    values_from_automate
  end
end
