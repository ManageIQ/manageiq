module ConfigDecryptPasswords
  def reload!
    Vmdb::Settings.decrypt_passwords!(super).tap do
      # The following should only be done when loading/reloading the current
      #   process' Settings, as opposed to a remote server's settings.
      Vmdb::Settings.on_reload if equal?(::Settings)
    end
  end

  alias load! reload!
end

Config::Options.prepend(ConfigDecryptPasswords)
