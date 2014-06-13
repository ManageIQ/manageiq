class Range
  # Iterates over rng, starting with the beginning of rng, incrementing by the
  # value, and passing that element to the block. Unlike +step+, +step_value+
  # invokes the + operator to iterate over the range elements. Unless the end is
  # excluded from the range, the final value of the iteration will always be the
  # end value, even if the increment value goes past the end of the range.
  #
  # This method has performance benefits over +step+ when working with ranges of
  # Time objects, for example, where step calling succ may be called an
  # inordinate number of times.
  #
  #    t = Time.now.midnight
  #    range = (t - 3.days)..t
  #    range.step_value(1.day) {|x| puts x}
  #
  # produces:
  #    Tue Dec 14 00:00:00 -0500 2010
  #    Wed Dec 15 00:00:00 -0500 2010
  #    Thu Dec 16 00:00:00 -0500 2010
  #    Fri Dec 17 00:00:00 -0500 2010
  #     
  def step_value(value)
    if block_given?
      return if self.begin > self.end

      iter = self.begin
      loop do
        yield iter unless iter == self.end && exclude_end?
        break if iter == self.end
        iter += value
        iter = self.end if iter > self.end
      end
      
      return self
    else
      ret = []
      step_value(value) { |v| ret << v }
      return ret
    end
  end
end
