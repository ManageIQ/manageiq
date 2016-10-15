class String
  def to_boolean
    if [true, 1, "1", "t", "T", "true", "TRUE", "on", "ON"].include? self
      return true
    elsif [false, 0, "0", "f", "F", "false", "FALSE", "off", "OFF"].include? self
      return false
    else
      return nil
    end
  end
end