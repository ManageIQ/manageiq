module Authenticator
  def self.for(config, username = nil)
    if username == 'admin'
      Database.new(config)
    else
      authenticator_class(config[:mode])&.new(config)
    end
  end

  def self.validate_config(config)
    return [] if config[:mode] == "none"

    authenticator = self.for(config)
    if authenticator
      authenticator.validate_config
    else
      [[:mode, "authentication mode, #{config[:mode].inspect}, is invalid. Should be one of: #{valid_modes.join(", ")}"]]
    end
  end

  private_class_method def self.valid_modes
    Base.subclasses.flat_map(&:authenticates_for).uniq << "none"
  end

  private_class_method def self.authenticator_class(name)
    authenticator_classes_cache[name.to_s]
  end

  private_class_method def self.authenticator_classes_cache
    @authenticator_classes_cache ||= Hash.new do |hash, name|
      hash[name] = authenticator_class_for(name)
    end
  end

  private_class_method def self.authenticator_class_for(name)
    Base.subclasses.find do |subclass|
      subclass.authenticates_for.include?(name)
    end
  end
end
