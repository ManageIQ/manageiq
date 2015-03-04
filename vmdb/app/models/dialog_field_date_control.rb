class DialogFieldDateControl < DialogField
  AUTOMATE_VALUE_FIELDS = %w(show_past_dates)

  include TimezoneMixin

  has_one :resource_action, :as => :resource, :dependent => :destroy

  after_initialize :default_resource_action

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
    if dynamic
      @value = values_from_automate
      @value
    else
      default_time
    end
  end

  def normalize_automate_values(automate_hash)
    self.class::AUTOMATE_VALUE_FIELDS.each do |key|
      send("#{key}=", automate_hash[key]) if automate_hash.key?(key)
    end

    return default_time if automate_hash["value"].blank?
    begin
      @value = Date.parse(automate_hash["value"]).iso8601
    rescue
      return default_time
    end

    Date.parse(@value).strftime("%m/%d/%Y")
  end

  def script_error_values
    "<Script error>"
  end

  private

  def default_resource_action
    build_resource_action if resource_action.nil?
  end

  def default_time
    with_current_user_timezone { Time.zone.now + 1.day }.strftime("%m/%d/%Y")
  end

  def values_from_automate
    DynamicDialogFieldValueProcessor.values_from_automate(self)
  end
end
