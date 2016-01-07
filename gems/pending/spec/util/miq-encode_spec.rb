require "spec_helper"
require 'util/miq-encode'

describe MIQEncode do
  it('.encode') { skip }
  it('.decode') { skip }
  it('.base64Encode') { skip }
  it('.base64Decode') { skip }

  it '.base24Decode' do
    byteArray = [0xbb, 0xe0, 0x11, 0xa1, 0x1b, 0x29, 0x3e, 0xa4, 0xd5, 0xc3, 0x97, 0x04, 0x1c, 0x7b, 0x02, 0x00]
    expect(MIQEncode.base24Decode(byteArray)).to eq("PX4FW-XP3BB-7Q99T-VVTPQ-XV8VF")
  end
end
