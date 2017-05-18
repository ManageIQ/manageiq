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
    authenticator_classes_cache[name.to_s]
  end

  def self.authenticator_classes_cache
    @authenticator_classes_cache ||= Concurrent::Hash.new do |hash, name|
      hash[name] = authenticator_class_for(name) || force_load_authenticator_for(name)
    end
  end

  def self.force_load_authenticator_for(name)
    # try to constantize in case the subclass is not loaded yet, but it still exists
    # this is happens with authenticators from provider gems
    subclass = "Authenticator::#{name.camelize}".safe_constantize
    subclass if subclass && subclass.authenticates_for.include?(name)
  end

  def self.authenticator_class_for(name)
    Base.subclasses.find do |subclass|
      subclass.authenticates_for.include?(name)
    end
  end
end
