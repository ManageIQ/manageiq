module MiqSqlite3DB
  def self.hiBit?(f)
    f & 0x80 == 0x80
  end

  # convert a var[1-9] to an integer
  def self.variableInteger(buf)
    raise "Empty Buffer" if buf.nil? || buf.size == 0
    bytes = []
    loop do
      byte = buf[bytes.size].ord
      bytes << byte
      break if !hiBit?(byte) || bytes.size == 9
    end

    value = 0
    bcnt  = 0
    bytes.each do |byte|
      bcnt += 1
      value <<= 7
      byte &= 0x7F  if bcnt < 9
      value |= byte
    end
    return value, bytes.size
  end

  def self.dumpHex(buf)
    out = ""
    buf.each_byte { |b| out += sprintf("%02x ", b) }
    out
  end
end
