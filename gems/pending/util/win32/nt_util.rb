# encoding: US-ASCII

module NtUtil
  def self.nt_filetime_to_ruby_time(nt_time)
    # Convert an NT FILETIME to a Ruby Time object.
    nt_time = nt_time / 10_000_000 - 11_644_495_200
    nt_time = 0 if nt_time < 0
    Time.at(nt_time).gmtime
  rescue RangeError
    nt_time
  end
end
