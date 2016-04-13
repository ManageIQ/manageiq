module ConfigDecryptPasswords
  def reload!
    Vmdb::Settings.decrypt_passwords!(super).tap do
      # Do not set the last_loaded when accessing a remote server's settings. It
      #   should only be set when reloading the current process' Settings.
      Vmdb::Settings.last_loaded = Time.now.utc if equal?(::Settings)
    end
  end

  alias load! reload!
end

Config::Options.prepend(ConfigDecryptPasswords)
