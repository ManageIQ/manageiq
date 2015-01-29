module MiqAeDefault
  extend ActiveSupport::Concern

  module ClassMethods
    def ae_default_value_for(name, hash)
      @default_hash ||= {}
      hash = {:value => hash} if hash.class != Hash
      @default_hash[name] = hash
    end

    def default_attributes
      @default_hash ||= {}
      @default_hash.keys
    end

    def value(key)
      @default_hash ||= {}
      return nil unless @default_hash.key?(key)
      @default_hash[key]
    end
  end

  def ae_defaults
    @attributes ||= {}
    self.class.default_attributes.each do |k|
      next if @attributes.key?(k)
      hash = self.class.value(k)
      value = hash[:value]
      value = value.call if value.class == Proc
      @attributes[k] = value
    end
  end
end
