module RequireNested
  # See also: include_concern
  def require_nested(name)
    filename = "#{self}::#{name}".underscore
    if Rails.application.config.cache_classes
      autoload name, filename
    else
      require_dependency filename
    end
  end
end

Module.send(:include, RequireNested)
