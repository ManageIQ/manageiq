# see also be_encrypted
# decryption doesn't always join unicode characters together correctly
# this matcher handles that case
RSpec::Matchers.define :be_decrypted do |expected|
  match do |actual|
    actual == utf8_to_ascii_bytestring(expected)
  end

  failure_message_for_should do |actual|
    "expected: #{actual.inspect} to be decrypted to #{utf8_to_ascii_bytestring(expected)}"
  end

  failure_message_for_should_not do |actual|
    "expected: #{actual.inspect} to not equal #{utf8_to_ascii_bytestring(expected)}"
  end

  description do
    "expect to be decrypted from a string (fixing utf8 encoding issues)"
  end

  def utf8_to_ascii_bytestring(str)
    str.bytes.map(&:chr).join
  end
end
