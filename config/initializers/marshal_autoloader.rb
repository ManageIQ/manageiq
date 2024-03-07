# Note, this is used to autoload constants serialized via marshal from one process and loaded in another such
# as through args in the MiqQueue. An alternative would be to eager load all of our autoload_paths in all
# processes or load just the classes that are marshaled, which may be far less classes and locations than when
# we originally wrote this initializer.
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
