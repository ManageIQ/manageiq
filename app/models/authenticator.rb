module Authenticator
  def self.for(config, username = nil)
    subclass_for(config, username).new(config)
  end

  def self.subclass_for(config, username)
    return Database if username == "admin"

    mode_class_name = config[:mode].camelize
    mode_class_name = 'Ldap' if mode_class_name == 'Ldaps'

    "Authenticator::#{mode_class_name}".constantize
  end
end
