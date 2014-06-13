class DialogFieldTextBox < DialogField

  def protected=(value)
    self.options[:protected] = value
  end

  def protected?
    self.options[:protected] == true
  end

  def automate_output_value
    return MiqPassword.encrypt(value) if self.protected?
    value
  end

  def automate_key_name
    return "password::#{super}" if self.protected?
    super
  end

end