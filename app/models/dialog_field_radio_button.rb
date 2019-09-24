class DialogFieldRadioButton < DialogFieldSortedItem
  def show_refresh_button?
    !!show_refresh_button
  end

  def initial_values
    [[nil, N_("<None>")]]
  end

  def force_multi_value
    false
  end

  private

  def raw_values
    @raw_values ||= dynamic ? values_from_automate : static_raw_values
    self.value ||= default_value if default_value_included?(@raw_values)

    @raw_values
  end

  def static_raw_values
    self[:values].to_miq_a
  end
end
