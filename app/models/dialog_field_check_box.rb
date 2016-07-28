class DialogFieldCheckBox < DialogField
  AUTOMATE_VALUE_FIELDS = %w(required read_only visible).freeze

  def checked?
    value == "t"
  end

  def value
    @value = values_from_automate if dynamic && @value.blank?
    @value
  end

  def initial_values
    false
  end

  def script_error_values
    "<Script error>"
  end

  def normalize_automate_values(automate_hash)
    self.class::AUTOMATE_VALUE_FIELDS.each do |key|
      send("#{key}=", automate_hash[key]) if automate_hash.key?(key)
    end

    return initial_values if automate_hash["value"].blank?
    automate_hash["value"].to_s
  end

  def refresh_json_value
    @value = values_from_automate
    {:checked => checked?, :read_only => read_only?, :visible => visible?}
  end

  def trigger_automate_value_updates
    values_from_automate
  end

  private

  def required_value_error?
    value != "t"
  end
end
