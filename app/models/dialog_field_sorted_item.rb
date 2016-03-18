class DialogFieldSortedItem < DialogField
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
      raise _("Invalid sort_order type <#{value}> specified.") % {:value => value}
    end
    options[:sort_order] = value.to_sym
  end

  def raw_values
    read_attribute(:values).to_miq_a
  end

  # Sort values before sending back
  def values
    values_data = raw_values
    sort_data(values_data)
  end

  def get_default_value
    values_data = values
    if values_data.count == 1
      values_data.first.first
    elsif values_data.detect { |v| v.first == default_value }
      default_value
    end
  end

  def script_error_values
    [[nil, "<Script error>"]]
  end

  def normalize_automate_values(automate_hash)
    %w(sort_by sort_order data_type default_value required read_only).each do |key|
      send("#{key}=", automate_hash[key]) if automate_hash.key?(key)
    end

    result = automate_hash["values"].to_a
    result.blank? ? initial_values : result
  end

  def trigger_automate_value_updates
    raw_values
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
end
