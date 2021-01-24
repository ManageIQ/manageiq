module DialogOptionMixin
  def self.get_dialog_option(key, value, from)
    # Return value - Support array and non-array types
    data = value.nil? ? from[key] : value
    data.kind_of?(Array) ? data.first : data
  end

  def get_dialog_option(key, value = nil)
    DialogOptionMixin.get_dialog_option(dialog_key(key), value, dialog_options)
  end

  def get_dialog_option_decrypted(key, value = nil)
    raise ArgumentError, "#{key} cannot be decrypted" unless dialog_option_encrypted?(key)

    enc_value = DialogOptionMixin.get_dialog_option(password_prefixed_key(key), value, dialog_options)
    MiqPassword.decrypt(enc_value)
  end

  def dialog_options
    options[:dialog]
  end

  def dialog_option_encrypted?(key)
    dialog_options.key?(password_prefixed_key(key))
  end

  def password_prefixed_key(key)
    key.to_s.start_with?("password::") ? key.to_s : "password::#{dialog_key(key)}"
  end

  def dialog_key(key)
    key.to_s.start_with?("dialog_") ? key.to_s : "dialog_#{key}"
  end
end
