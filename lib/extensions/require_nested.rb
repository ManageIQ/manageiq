module RequireNested
  # See also: include_concern
  def require_nested(name)
    return if const_defined?(name, false)

    filename = "#{self}::#{name}".underscore
    filename = "#{name}".underscore if self == Object
    if Rails.application.config.cache_classes
      autoload name, filename
    else
      require_dependency filename
    end

    if ActiveSupport::Dependencies.search_for_file("#{name}".underscore) && self != Object
      Object.require_nested name
    end
  end
end

Module.send(:include, RequireNested)
