class DialogFieldTextBox < DialogField
  AUTOMATE_VALUE_FIELDS = %w(data_type protected required validator_rule validator_type read_only visible description).freeze

  def initialize_value_context
    if @value.blank?
      @value = dynamic && load_values_on_init? ? values_from_automate : default_value
    end
  end

  def value
    return nil if @value.nil?
    convert_value_to_type
  end

  def initial_values
    ""
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
    return nil if @value.nil?
    return MiqPassword.encrypt(@value) if self.protected? && !value_is_already_encrypted?
    convert_value_to_type
  end

  def automate_key_name
    return "password::#{super}" if self.protected?
    super
  end

  def validate_field_data(dialog_tab, dialog_group)
    return if !required? && @value.blank? || !visible

    return "#{dialog_tab.label}/#{dialog_group.label}/#{label} is required" if required? && @value.blank?
    return "#{dialog_tab.label}/#{dialog_group.label}/#{label} must be an integer" if value_supposed_to_be_int?

    # currently only regex is supported
    rule = validator_rule if validator_type == 'regex'

    return unless rule
    "#{dialog_tab.label}/#{dialog_group.label}/#{label} is invalid" unless @value.to_s =~ /#{rule}/
  end

  def script_error_values
    N_("<Script error>")
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

    {:text => @value, :read_only => read_only?, :visible => visible?}
  end

  private

  def convert_value_to_type
    data_type == "integer" ? @value.to_i : @value
  end

  def value_supposed_to_be_int?
    data_type == "integer" && @value.to_s !~ /^[0-9]+$/
  end

  def load_values_on_init?
    return true unless show_refresh_button
    load_values_on_init
  end

  def value_is_already_encrypted?
    return true if MiqPassword.encrypted?(@value)
  end
end
