# encoding: US-ASCII

module NtUtil

  def NtUtil.NtToRubyTime(ntTime)
    # Convert an NT FILETIME to a Ruby Time object.
    begin
      ntTime = ntTime / 10000000 - 11644495200
      ntTime = 0 if ntTime < 0
      Time.at(ntTime).gmtime
    rescue RangeError
      ntTime
    end
  end
end