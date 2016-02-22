module ReservedMixin
  extend ActiveSupport::Concern
  included do
    has_one :reserved_rec, :class_name => "::Reserve", :as => :resource,
      :autosave => true, :dependent => :delete
  end

  module ClassMethods
    # Dynamically creates a getter, setter, and ? method that uses the
    #   reserved column as a Hash to store the value.
    def reserve_attribute(name, type)
      name = name.to_sym

      attribute name, type

      define_method(name)       { reserved_hash_get(name) }
      define_method("#{name}?") { !!reserved_hash_get(name) }
      define_method("#{name}=") do |val|
        send("#{name}_will_change!")
        reserved_hash_set(name, val)
      end
    end
  end

  def reserved_hash_get(key)
    res = reserved
    res && res[key]
  end

  def reserved_hash_set(key, val)
    res = (reserved || {})
    if val.nil?
      res.delete(key)
    else
      res[key] = val
    end
    self.reserved = res
    val
  end

  # Migrate values from the reserved hash to a column.  Accepts either
  #   an Array of key names when the column names match the key names, or
  #   a Hash of key names to column names if the column names do not match the
  #   key names
  def reserved_hash_migrate(*keys)
    keys = keys.flatten
    if keys.last.kind_of?(Hash)
      keys = keys.last
    else
      keys = keys.zip(keys) # [:key1, :key2] => [[:key1, :key1], [:key2, :key2]]
    end

    keys.each do |key, attribute|
      val = reserved_hash_get(key)
      reserved_hash_set(key, nil)
      send("#{attribute}=", val)
    end
    self.save!
  end

  def reserved
    reserved_rec.try(:reserved)
  end

  def reserved=(val)
    res = reserved_rec
    if val.blank?
      self.reserved_rec = nil
    elsif res.nil?
      build_reserved_rec(:reserved => val)
    else
      res.reserved = val
    end
    val
  end
end
