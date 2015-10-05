class Hash
  def deep_clone
    Marshal.load(Marshal.dump(self))
  end

  def deep_delete(key)
    key = [key] unless key.kind_of?(Array)
    key.each { |k| delete(k) }
    each_value { |v| v.deep_delete(key) if v.respond_to?(:deep_delete) }
    self
  end
end

class Array
  def deep_clone
    Marshal.load(Marshal.dump(self))
  end

  def deep_delete(key)
    each { |i| i.deep_delete(key) if i.respond_to?(:deep_delete) }
    self
  end
end
