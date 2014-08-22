class DialogFieldCheckBox < DialogField
  private

  def required_value_error?
    value != "t"
  end
end
