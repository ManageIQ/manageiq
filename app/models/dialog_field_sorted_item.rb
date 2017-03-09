class DialogFieldSortedItem < DialogField
  AUTOMATE_VALUE_FIELDS = %w(sort_by sort_order data_type default_value required read_only visible).freeze

  def initialize_with_values(dialog_values)
    if load_values_on_init?
      raw_values
      @value = value_from_dialog_fields(dialog_values) || default_value
    else
      @raw_values = initial_values
    end
  end

  def sort_by
    options[:sort_by] || :description
  end

  def sort_by=(value)
    unless [:value, :description, :none].include?(value.to_sym)
      raise _("Invalid sort_by type <%{value}> specified.") % {:value => value}
    end
    options[:sort_by] = value.to_sym
  end

  def sort_order
    options[:sort_order] || :ascending
  end

  def sort_order=(value)
    unless [:ascending, :descending].include?(value.to_sym)
      raise _("Invalid sort_order type <%{value}> specified.") % {:value => value}
    end
    options[:sort_order] = value.to_sym
  end

  # Sort values before sending back
  def values
    values_data = raw_values
    sort_data(values_data)
  end

  def get_default_value
    trigger_automate_value_updates
    default_value
  end

  def script_error_values
    [[nil, "<Script error>"]]
  end

  def normalize_automate_values(automate_hash)
    AUTOMATE_VALUE_FIELDS.each do |key|
      send("#{key}=", automate_hash[key]) if automate_hash.key?(key)
    end

    result = automate_hash["values"].to_a
    result.blank? ? initial_values : result
  end

  def trigger_automate_value_updates
    self.default_value = nil if dynamic
    @raw_values = nil
    raw_values
  end

  def refresh_json_value(checked_value)
    self.default_value = nil
    @raw_values = nil

    refreshed_values = values

    @value = if refreshed_values.collect { |value_pair| value_pair[0].to_s }.include?(checked_value)
               checked_value
             else
               default_value
             end

    {:refreshed_values => refreshed_values, :checked_value => @value, :read_only => read_only?, :visible => visible?}
  end

  private

  def sort_data(data_to_sort)
    return data_to_sort if sort_by == :none

    value_position = sort_by == :value ? :first : :last
    value_modifier = data_type == "integer" ? :to_i : :to_s

    data_to_sort = data_to_sort.sort_by { |d| d.send(value_position).send(value_modifier) }
    return data_to_sort.reverse! if sort_order == :descending
    data_to_sort
  end

  def raw_values
    @raw_values ||= dynamic ? values_from_automate : static_raw_values
    use_first_value_as_default unless default_value_included_in_raw_values?
    self.value ||= default_value

    @raw_values
  end

  def use_first_value_as_default
    self.default_value = sort_data(@raw_values).first.try(:first)
  end

  def default_value_included_in_raw_values?
    @raw_values.collect { |value_pair| value_pair[0] }.include?(default_value)
  end

  def static_raw_values
    first_values = required? ? [[nil, "<Choose>"]] : initial_values
    first_values + self[:values].to_miq_a.reject { |value| value[0].nil? }
  end

  def initial_values
    [[nil, "<None>"]]
  end

  def load_values_on_init?
    return true unless show_refresh_button
    load_values_on_init
  end
end
