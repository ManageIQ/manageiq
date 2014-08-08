class DialogFieldTextBox < DialogField

  def protected=(value)
    self.options[:protected] = value
  end

  def protected?
    self.options[:protected] == true
  end

  def value_from_dialog_fields(dialog_values)
    value = dialog_values[automate_key_name]
    self.protected? ? MiqPassword.decrypt(value) : value
  end

  def automate_output_value
    return MiqPassword.encrypt(value) if self.protected?
    value
  end

  def automate_key_name
    return "password::#{super}" if self.protected?
    super
  end

  def validate(dialog_tab, dialog_group)
    case validator_type
    when 'regex'
      return "#{dialog_tab.label}/#{dialog_group.label}/#{label} is invalid" unless value.match(/#{validator_rule}/)
    end
    super
  end
end
