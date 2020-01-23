module ConfigDecryptPasswords
  def reload!
    Vmdb::Settings.decrypt_passwords!(super).tap do
      # The following should only be done when loading/reloading the current
      #   process' Settings, as opposed to a remote server's settings.
      Vmdb::Settings.dump_to_log_directory(::Settings) if equal?(::Settings)
    end
  end

  alias load! reload!
end

Config::Options.prepend(ConfigDecryptPasswords)
Config::Options.include(MoreCoreExtensions::Shared::Nested)
