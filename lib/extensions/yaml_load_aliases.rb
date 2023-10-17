module YamlLoadAliases
  DEFAULT_PERMITTED_CLASSES = [Regexp, Symbol, Date, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone]
  # Psych 4 aliases load as safe_load.  Some loads happen early, like reading the database.yml so we don't want to load our
  # constants at that time, such as MiqExpression, Ruport, so we have two sets of permitted classes.
  def safe_load(*args, **kwargs)
    super(*args, **kwargs.merge(:aliases => true).reverse_merge(:permitted_classes => DEFAULT_PERMITTED_CLASSES))
  rescue NameError => err
    warn "WARNING: Trying Permitted Classes due to NameError: #{err}"
    super(*args, **kwargs.merge(:aliases => true).reverse_merge(:permitted_classes => DEFAULT_PERMITTED_CLASSES + [MiqExpression, MiqReport, Ruport::Data::Table, Ruport::Data::Record]))
  rescue Psych::DisallowedClass => err
    # Temporary hack to fallback to psych 3 behavior to go back to unsafe load if it's a disallowed class.
    # See: https://stackoverflow.com/questions/71191685/visit-psych-nodes-alias-unknown-alias-default-psychbadalias/71192990#71192990
    # The alternative is to enumerate all the classes we will allow to be loaded from YAML, such as many of the various models.
    warn "WARNING: Using fallback due to DisallowedClass: #{err}"
    unsafe_load(*args, **(kwargs.slice(:filename, :fallback, :symbolize_names, :freeze)))
  end
end

if Psych::VERSION >= "4.0"
  require 'yaml'
  YAML.singleton_class.prepend(YamlLoadAliases)
end
