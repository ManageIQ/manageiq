class DialogFieldRadioButton < DialogFieldSortedItem
  def show_refresh_button?
    !!show_refresh_button
  end

  def initial_values
    [[nil, "<None>"]]
  end

  private

  def raw_values
    @raw_values ||= dynamic ? values_from_automate : static_raw_values

    self.value ||= default_value if @raw_values.collect { |value_pair| value_pair[0] }.include?(default_value)

    @raw_values
  end

  def static_raw_values
    self[:values].to_miq_a
  end
end
