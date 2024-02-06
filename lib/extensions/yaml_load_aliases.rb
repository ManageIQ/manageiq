module YamlLoadAliases
  # Psych 4 aliases load as safe_load.  Some loads happen early, like reading the database.yml so we don't want to load our
  # constants at that time, such as MiqExpression, Ruport, so we have two sets of permitted classes.
  def safe_load(yaml, permitted_classes: [], aliases: false, **kwargs)
    # permitted_classes kwarg is provided because rails 6.1.7.x expects it as a defined kwarg.  See: https://github.com/rails/rails/blob/9ab33753b6bab1809fc73d35b98a5c1d0c96ba1b/activerecord/lib/active_record/coders/yaml_column.rb#L52
    permitted_classes += YamlPermittedClasses.permitted_classes
    super(yaml, permitted_classes: permitted_classes, aliases: true, **kwargs)
  rescue Psych::DisallowedClass => err
    # Temporary hack to fallback to psych 3 behavior to go back to unsafe load if it's a disallowed class.
    # See: https://stackoverflow.com/questions/71191685/visit-psych-nodes-alias-unknown-alias-default-psychbadalias/71192990#71192990
    # The alternative is to enumerate all the classes we will allow to be loaded from YAML, such as many of the various models.
    raise unless Rails.env.production?

    warn "WARNING: Using fallback to unsafe_load due to DisallowedClass: #{err}"
    unsafe_load(yaml, **kwargs.except(:aliases, :permitted_classes, :permitted_symbols))
  end
end

require 'yaml'
YAML.singleton_class.prepend(YamlLoadAliases)
