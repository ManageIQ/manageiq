module MarshalAutoloader
  def load(data)
    super
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
end
module Marshal
  class << self
    prepend MarshalAutoloader
  end
end
