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

  # Make a reference (upper two bytes are seq num, lower six are entry).
  def NtUtil.MkRef(ref)
    ref.divmod(2 ** 48)
  end
  
  def NtUtil.gotBit?(flags, bit)
		(flags & bit) == bit
	end
	
  # Process per-sector "fixups" that NTFS uses to detect corruption of
  # multi-sector data structures, like MFT records.
  def NtUtil.process_fixups(buf, fixup_offset, usa_offset, usa_count)
    #
    # The signature value we must look for is stored just before the fix-up array.
    #
    fu_sig = buf[usa_offset, 2].unpack('S')[0]

    #
    # For each end-of-sector, check that the last two bytes equal the fixup signature.
    # If so, replace them with original data stored in the update sequence array.
    #
    1.upto(usa_count - 1) do |i|
      sig = buf[i * fixup_offset - 2, 2].unpack('S')[0]
      raise "NTFS Fixup Error: fixup signature:<#{fu_sig}> does not match signature[#{i}]=<#{sig}> - consider running chkdsk" if sig != fu_sig
      buf[i * fixup_offset - 2, 2] = buf[i * 2 + usa_offset, 2]
    end

    return buf
  end

  def NtUtil.validate_signature(signature, expected)
    if signature != expected
      raise "Uninitialized"   if signature == "\000\000\000\000"
      raise "Bad Sector"      if signature == 'BAAD'
      raise "Invalid Signature <#{signature}>"
    end
  end

end

# Format numeric data (thousands grouping).
class Numeric
  
  def format(separator = ',', decimal_point = '.')
    num_parts = self.to_s.split('.')
    x = num_parts[0].reverse.scan(/\d{1,3}-?/).join(separator).reverse
    x << decimal_point + num_parts[1] if num_parts.length == 2
    x
  end
  
  def Numeric.format(number, *args)
    number.format(*args)
  end
end
