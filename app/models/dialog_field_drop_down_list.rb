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
end
