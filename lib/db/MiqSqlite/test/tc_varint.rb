require 'test/unit'
require_relative '../MiqSqlite3'

class TestSqlite < Test::Unit::TestCase
  
	#  Cell content makes use of variable length integers.  A variable
  #  length integer is 1 to 9 bytes where the lower 7 bits of each 
  #  byte are used.  The integer consists of all bytes that have bit 8 set and
  #  the first byte with bit 8 clear.  The most significant byte of the integer
  #  appears first.  A variable-length integer may not be more than 9 bytes long.
  #  As a special case, all 8 bytes of the 9th byte are used as data.  This
  #  allows a 64-bit integer to be encoded in 9 bytes.
  # 
  #     0x00                      becomes  0x00000000
  #     0x7f                      becomes  0x0000007f
  #     0x81 0x00                 becomes  0x00000080
  #     0x82 0x00                 becomes  0x00000100
  #     0x80 0x7f                 becomes  0x0000007f
  #     0x8a 0x91 0xd1 0xac 0x78  becomes  0x12345678
  #     0x81 0x81 0x81 0x81 0x01  becomes  0x10204081
  
	def test_varint
	  assert_equal(0x00000000, get_varint("\x00"))
	  assert_equal(0x0000007f, get_varint("\x7f"))
	  assert_equal(0x00000080, get_varint("\x81\x00"))
	  assert_equal(0x00000100, get_varint("\x82\x00"))
	  assert_equal(0x0000007f, get_varint("\x80\x7f"))
	  assert_equal(0x12345678, get_varint("\x81\x91\xd1\xac\x78"))  # For some reason, the example in the comments is wrong!
	  assert_equal(0x10204081, get_varint("\x81\x81\x81\x81\x01"))
	end

  def get_varint(buf)
    value, count = MiqSqlite3DB.variableInteger(buf)
    return value
  end

end
