class DialogFieldSortedItem < DialogField
  AUTOMATE_VALUE_FIELDS = %w(sort_by sort_order data_type default_value required read_only visible description).freeze

  def initialize_value_context
    if load_values_on_init
      raw_values
    else
      @raw_values = initial_values
    end
  end

  def initialize_with_given_value(given_value)
    raw_values
    self.default_value = given_value
  end

  def sort_by
    options[:sort_by].try(:to_sym) || :description
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

  def values
    raw_values
  end

  def extract_dynamic_values
    @raw_values
  end

  def get_default_value
    trigger_automate_value_updates
    default_value
  end

  def script_error_values
    [[nil, N_("<Script error>")]]
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

  def force_multi_value
    # override in subclasses
    nil
  end

  private

  def add_nil_option
    @raw_values.unshift(nil_option).reject!(&:empty?)
  end

  def default_value_if_included
    default_value if default_value_included?(@raw_values)
  end

  def sort_data(data_to_sort)
    return data_to_sort if sort_by == :none

    value_position = sort_by == :value ? :first : :last

    data_to_sort = data_to_sort.sort_by { |d| d.send(value_position).send(value_modifier) }
    return data_to_sort.reverse! if sort_order == :descending
    data_to_sort
  end

  def determine_selected_value
    use_first_value_as_default unless default_value_included?(@raw_values)
    self.value ||= default_value.nil? && data_type == "integer" ? nil : default_value.send(value_modifier)
  end

  def raw_values
    @raw_values ||= dynamic ? values_from_automate : static_raw_values
    reject_extraneous_nil_values unless dynamic?
    @raw_values = sort_data(@raw_values)
    add_nil_option unless dynamic? || multiselect?
    determine_selected_value
    @raw_values
  end

  def multiselect?
    false
  end

  def reject_extraneous_nil_values
    @raw_values = @raw_values.reject { |value| value[0].nil? }
  end

  def use_first_value_as_default
    self.default_value = sort_data(@raw_values).first.try(:first)
  end

  def default_value_included?(values_list)
    values_list.collect { |value_pair| value_pair[0].send(value_modifier) }.include?(default_value.send(value_modifier))
  end

  def static_raw_values
    Array.wrap(self[:values]).reject { |value| value[0].nil? }.reject(&:empty?)
  end

  def initial_values
    [[nil, N_("<None>")]]
  end

  def initial_required_values
    [nil, N_("<Choose>")]
  end

  def nil_option
    if !required?
      initial_values.flatten
    elsif default_value.blank? || !default_value_included?(self[:values])
      initial_required_values
    else
      []
    end
  end

  def value_modifier
    data_type == "integer" ? :to_i : :to_s
  end
end
