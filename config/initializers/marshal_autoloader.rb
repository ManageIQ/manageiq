module Marshal
  def self.load_with_autoload_missing_constants(data)
    load_without_autoload_missing_constants(data)
  rescue ArgumentError => error
    if error.to_s.include?('undefined class')
      begin
        error.to_s.split.last.constantize
      rescue NameError
        raise error
      end
      retry
    end
    raise error
  end
  class << self
    alias_method_chain :load, :autoload_missing_constants
  end
end
