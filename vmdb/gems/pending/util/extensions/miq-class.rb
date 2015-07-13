class Class
  def hierarchy
    sc = self.superclass
    return [self] if sc.nil?
    return sc.hierarchy.unshift(self)
  end

  def subclass_of?(c)
    return false if self == c
    hierarchy.include?(c)
  end
  alias is_subclass_of? subclass_of?

  def is_or_subclass_of?(c)
    hierarchy.include?(c)
  end

  def superclass_of?(c)
    c.subclass_of?(self)
  end
  alias is_superclass_of? superclass_of?

  def is_or_superclass_of?(c)
    c.is_or_subclass_of?(self)
  end
end
