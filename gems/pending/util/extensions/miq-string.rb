require 'util/miq-encode'

require 'active_support/inflector'
require 'more_core_extensions/core_ext/string'

class String
  def miqEncode
    MIQEncode.encode(self)
  end

  # Support with IEC size format
  # http://physics.nist.gov/cuu/Units/binary.html
  IEC_SIZE_SUFFIXES = %w(Ki Mi Gi Ti).freeze
  def to_iec_integer
    exp_index = IEC_SIZE_SUFFIXES.index(self[-2..-1])
    if exp_index.nil?
      Integer(self)
    else
      Integer(self[0..-3]) * 1024**(exp_index + 1)
    end
  end
end
