class DialogFieldDateControl < DialogField
  AUTOMATE_VALUE_FIELDS = %w(show_past_dates)

  include TimezoneMixin

  def show_past_dates
    self.options[:show_past_dates] || false
  end

  def show_past_dates=(value)
    self.options[:show_past_dates] = value
  end

  def automate_output_value
    return nil unless @value
    Date.parse(@value).iso8601
  end

  def value
    @value = dynamic ? values_from_automate : default_time if @value.blank?

    Date.parse(@value).strftime("%m/%d/%Y")
  end

  def normalize_automate_values(automate_hash)
    self.class::AUTOMATE_VALUE_FIELDS.each do |key|
      send("#{key}=", automate_hash[key]) if automate_hash.key?(key)
    end

    return default_time if automate_hash["value"].blank?
    begin
      return DateTime.parse(automate_hash["value"]).iso8601
    rescue
      return default_time
    end
  end

  def script_error_values
    "<Script error>"
  end

  def refresh_json_value
    @value = values_from_automate

    {:date => Date.parse(@value).strftime("%m/%d/%Y")}
  end

  private

  def default_time
    with_current_user_timezone { Time.zone.now + 1.day }.strftime("%m/%d/%Y")
  end

  def values_from_automate
    DynamicDialogFieldValueProcessor.values_from_automate(self)
  end
end
