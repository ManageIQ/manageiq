module Authenticator
  require_nested :Base
  require_nested :Database
  require_nested :Httpd
  require_nested :Ldap

  def self.for(config, username = nil)
    if username == 'admin'
      Database.new(config)
    else
      authenticator_class(config[:mode]).new(config)
    end
  end

  def self.authenticator_class(name)
    name = name.to_s
    Base.subclasses.find do |subclass|
      return subclass if subclass.authenticates_for.include?(name)
    end

    # try to constantize in case the subclass is not loaded yet, but it still exists
    # this is happens with authenticators from provider gems
    "Authenticator::#{name.camelize}".safe_constantize
  end
end
