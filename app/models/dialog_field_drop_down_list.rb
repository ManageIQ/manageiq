class DialogFieldDropDownList < DialogFieldSortedItem
  def show_refresh_button?
    !!show_refresh_button
  end

  def multi_value?
    return true if options[:force_multi_value].present? && options[:force_multi_value] != "null"
  end

  def force_multi_value=(setting)
    options[:force_multi_value] = setting
  end

  def initial_values
    [[nil, "<None>"]]
  end

  def refresh_json_value(checked_value)
    @raw_values = @default_value = nil

    refreshed_values = values

    if refreshed_values.collect { |value_pair| value_pair[0].to_s }.include?(checked_value)
      @value = checked_value
    else
      @value = @default_value
    end

    {:refreshed_values => refreshed_values, :checked_value => @value, :read_only => read_only?, :visible => visible?}
  end

  def automate_output_value
    return nil if @value.blank?
    MiqAeEngine.create_automation_attribute_array_value(@value.split.map(&:to_i))
  end

  private

  def load_values_on_init?
    return true unless show_refresh_button
    load_values_on_init
  end
end
