class DialogFieldSortedItem < DialogField
  def sort_by
    self.options[:sort_by] || :description
  end

  def sort_by=(value)
    raise "Invalid sort_by type <#{value}> specified." unless [:value, :description, :none].include?(value.to_sym)
    self.options[:sort_by] = value.to_sym
  end

  def sort_order
    self.options[:sort_order] || :ascending
  end

  def sort_order=(value)
    raise "Invalid sort_order type <#{value}> specified." unless [:ascending, :descending].include?(value.to_sym)
    self.options[:sort_order] = value.to_sym
  end

  def raw_values
    self.read_attribute(:values).to_miq_a
  end

  # Sort values before sending back
  def values
    sort_field = self.sort_by
    values_data = raw_values
    return values_data if sort_field == :none

    value_position = sort_field     == :value    ? :first : :last
    value_modifier = self.data_type == "integer" ? :to_i  : :to_s

    values_data = values_data.sort_by {|d| d.send(value_position).send(value_modifier)}
    return values_data.reverse! if sort_order == :descending
    values_data
  end

  def get_default_value
    values_data = values
    if values_data.count == 1
      values_data.first.first
    elsif values_data.detect { |v| v.first == default_value }
      default_value
    end
  end
end
