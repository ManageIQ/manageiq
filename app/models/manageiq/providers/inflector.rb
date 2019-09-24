module ManageIQ::Providers::Inflector
  class ObjectNotNamespacedError < StandardError; end

  def self.provider_name(class_or_instance)
    klass = class_or_instance.class == Class ? class_or_instance : class_or_instance.class
    provider_module(klass).name.split('::').last
  end

  def self.manager_type(class_or_instance)
    klass = class_or_instance.class == Class ? class_or_instance : class_or_instance.class
    manager = (klass.name.split('::') - provider_module(klass).name.split('::')).first
    manager.chomp('Manager')
  end

  def self.provider_module(klass, original_object = nil)
    if klass == Object
      raise ObjectNotNamespacedError, "Cannot get provider module from non namespaced object #{original_object}"
    end

    klass.parent == ManageIQ::Providers ? klass : provider_module(klass.parent, klass)
  end
end
