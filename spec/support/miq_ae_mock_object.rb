class MiqAeMockObject
  attr_reader :parent
  def initialize(hash = {})
    @object_hash = HashWithIndifferentAccess.new(hash)
  end

  def attributes
    @object_hash
  end

  def parent=(obj)
    @parent = obj
  end

  def [](attr)
    @object_hash[attr.downcase]
  end

  def []=(attr, value)
    @object_hash[attr.downcase] = value
  end
end
