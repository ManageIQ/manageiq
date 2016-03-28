module ConfigDecryptPasswords
  def reload!
    Vmdb::Settings.decrypt_passwords!(super)
  end

  alias load! reload!
end

Config::Options.prepend(ConfigDecryptPasswords)
