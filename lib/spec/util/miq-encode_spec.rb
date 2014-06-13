require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. util})))
require 'miq-encode'

describe MIQEncode do
	it('.encode') { pending }
  it('.decode') { pending }
  it('.base64Encode') { pending }
  it('.base64Decode') { pending }

  it '.base24Decode' do
		byteArray = [0xbb, 0xe0, 0x11, 0xa1, 0x1b, 0x29, 0x3e, 0xa4, 0xd5, 0xc3, 0x97, 0x04, 0x1c, 0x7b, 0x02, 0x00]
		MIQEncode.base24Decode(byteArray).should == "PX4FW-XP3BB-7Q99T-VVTPQ-XV8VF"
	end
end
