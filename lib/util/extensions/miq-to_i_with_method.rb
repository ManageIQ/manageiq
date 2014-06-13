class String
  NUMBER_WITH_METHOD_REGEX = /^([0-9\.,]+)\.([a-z]+)$/

  def to_i_with_method
    to_x_with_method.to_i
  end

  def to_f_with_method
    to_x_with_method.to_f
  end

  def to_x_with_method
    n = self.gsub(',', '')
    return n unless n =~ NUMBER_WITH_METHOD_REGEX && $2 != "percent"
    n = $1.include?('.') ? $1.to_f : $1.to_i
    n.send($2)
  end
  private :to_x_with_method

  def number_with_method?
    self =~ NUMBER_WITH_METHOD_REGEX
  end
end

class Numeric
  def to_i_with_method
    self.to_i # Can't alias because method is defined in subclasses
  end

  def to_f_with_method
    self.to_f # Can't alias because method is defined in subclasses
  end
end

class NilClass
  alias to_i_with_method to_i
  alias to_f_with_method to_f
end

class Object
  def number_with_method?
    false
  end
end
