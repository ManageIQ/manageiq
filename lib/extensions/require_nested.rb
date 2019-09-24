module RequireNested
  # See also: include_concern
  def require_nested(name)
    return if const_defined?(name, false)

    filename = "#{self}::#{name}".underscore
    filename = name.to_s.underscore if self == Object
    if Rails.application.config.cache_classes
      autoload name, filename
    else
      require_dependency filename
    end

    if ActiveSupport::Dependencies.search_for_file(name.to_s.underscore) && self != Object
      Object.require_nested name
    end
  end

  def require_nested_all
    path = File.join(caller(1, 1).first.split('.rb').first, "*.rb") # determining caller file location
    Dir.glob(path).sort.each do |full_path|
      name = File.basename(full_path, '.rb')
      require_nested(name.classify.to_sym)
    end
  end
end

Module.include RequireNested
