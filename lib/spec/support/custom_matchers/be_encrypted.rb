# See also be_decrypted
# decryption doesn't always join unicode characters together correctly. this should not cause an issue
RSpec::Matchers.define :be_encrypted do |expected|
  match do |actual|
    MiqPassword.encrypted?(actual) && (
      expected.nil? ||
      MiqPassword.decrypt(actual) == utf8_to_ascii_bytestring(expected)
    )
  end

  failure_message_for_should do |actual|
    "expected: #{actual.inspect} to be encrypted#{ " and decrypt to #{expected}" if expected}"
  end

  failure_message_for_should_not do |actual|
    "expected: #{actual.inspect} not to be encrypted"
  end

  description do
    "expect to be an encrypted v2 password (with optional encrypted value)"
  end

  def utf8_to_ascii_bytestring(str)
    str.bytes.map(&:chr).join
  end
end
