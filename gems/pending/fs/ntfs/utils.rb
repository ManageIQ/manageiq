# encoding: US-ASCII

module NTFS
  module Utils
    # Make a reference (upper two bytes are seq num, lower six are entry).
    def self.MkRef(ref)
      ref.divmod(2**48)
    end

    def self.gotBit?(flags, bit)
      (flags & bit) == bit
    end

    # Process per-sector "fixups" that NTFS uses to detect corruption of
    # multi-sector data structures, like MFT records.
    def self.process_fixups(buf, fixup_offset, usa_offset, usa_count)
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

      buf
    end

    def self.validate_signature(signature, expected)
      if signature != expected
        raise "Uninitialized"   if signature == "\000\000\000\000"
        raise "Bad Sector"      if signature == 'BAAD'
        raise "Invalid Signature <#{signature}>"
      end
    end
  end
end
