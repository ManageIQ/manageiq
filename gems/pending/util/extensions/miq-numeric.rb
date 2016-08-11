require 'more_core_extensions/core_ext/numeric'

class Numeric
  def apply_min_max(min, max)
    value = self
    value = [value, min].max if min
    value = [value, max].min if max
    value
  end
end
