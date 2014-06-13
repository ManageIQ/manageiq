class Numeric
  def round_up(nearest = 1)
    return self if nearest == 0
    return self if (self % nearest) == 0
    self + nearest - (self % nearest)
  end

  def round_down(nearest = 1)
    return self if nearest == 0
    return self if (self % nearest) == 0
    self - (self % nearest)
  end

  def apply_min_max(min, max)
    value = self
    value = [value, min].max if min
    value = [value, max].min if max
    value
  end
end
