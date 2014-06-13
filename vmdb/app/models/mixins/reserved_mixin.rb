module ReservedMixin
  extend ActiveSupport::Concern
  included do
    has_one :reserved_rec, :class_name => "::Reserve", :as => :resource, :dependent => :delete

    # Override the method used by save and save!
    def create_or_update_with_reserved
      # Touch the current record, but don't save it yet
      current_time = current_time_from_proper_timezone
      write_attribute('updated_at', current_time) if respond_to?(:updated_at)
      write_attribute('updated_on', current_time) if respond_to?(:updated_on)

      ret = create_or_update_without_reserved
      res = self.reserved_rec
      res.save! if res
      ret
    end
    alias_method_chain :create_or_update, :reserved

    # Dynamically creates a getter, setter, and ? method that uses the
    #   reserved column as a Hash to store the value.
    def self.attr_via_reserved(*attributes)
      attributes.each do |attribute|
        attribute = attribute.to_sym
        define_method(attribute)       { reserved_hash_get(attribute) }
        define_method("#{attribute}?") { !!reserved_hash_get(attribute) }
        define_method("#{attribute}=") { |val| reserved_hash_set(attribute, val) }
      end
    end
  end

  def reserved_hash_get(key)
    res = self.reserved
    return res && res[key]
  end

  def reserved_hash_set(key, val)
    res = (self.reserved || {})
    if val.nil?
      res.delete(key)
    else
      res[key] = val
    end
    self.reserved = res
    return val
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
      self.send("#{attribute}=", val)
    end
    self.save!
  end

  def reserved
    self.reserved_rec.try(:reserved)
  end

  def reserved=(val)
    res = self.reserved_rec
    if val.blank?
      self.reserved_rec = nil
    elsif res.nil?
      self.build_reserved_rec(:reserved => val)
    else
      res.reserved = val
    end
    return val
  end
end
