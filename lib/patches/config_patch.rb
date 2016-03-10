module ConfigDecryptPasswords
  def reload!
    Vmdb::Settings.decrypt_passwords!(super)
  end

  alias_method :load!, :reload!
end

Config::Options.prepend(ConfigDecryptPasswords)
