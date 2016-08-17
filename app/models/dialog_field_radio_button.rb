class DialogFieldRadioButton < DialogFieldSortedItem
  def show_refresh_button?
    !!show_refresh_button
  end

  def initial_values
    [["", "<None>"]]
  end

  def refresh_json_value(checked_value)
    @raw_values = @default_value = nil

    refreshed_values = values

    if refreshed_values.collect { |value_pair| value_pair[0].to_s }.include?(checked_value)
      @value = checked_value
    else
      @value = @default_value
    end

    {:refreshed_values => refreshed_values, :checked_value => @value, :read_only => read_only?}
  end

  private

  def load_values_on_init?
    return true unless show_refresh_button
    load_values_on_init
  end
end
