class MiqIECUnits
  IEC_SIZE_SUFFIXES = %w(Ki Mi Gi Ti)

  def self.string_to_value(value)
    exp_index = IEC_SIZE_SUFFIXES.index(value[-2..-1])
    if exp_index.nil?
      return Integer(value)
    else
      return Integer(value[0..-3]) * 1024**(exp_index + 1)
    end
  end
end
