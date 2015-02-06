class DialogFieldCheckBox < DialogField
  AUTOMATE_VALUE_FIELDS = %w(default_value required)

  has_one :resource_action, :as => :resource, :dependent => :destroy

  after_initialize :default_resource_action

  def checked?
    ['1', 't'].include?(default_value)
  end

  def default_value
    write_attribute(:default_value, values_from_automate) if dynamic
    read_attribute(:default_value)
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

    return initial_values if automate_hash["default_value"].blank?
    automate_hash["default_value"].to_s
  end

  private

  def default_resource_action
    build_resource_action if resource_action.nil?
  end

  def required_value_error?
    value != "t"
  end

  def values_from_automate
    DynamicDialogFieldValueProcessor.values_from_automate(self)
  end
end
