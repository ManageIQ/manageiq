
# NOTE: If this fails, this may be due to special characters in the password, or passing in an encrypted password
# possible solutions:
#   field.should be_encrypted_version(1)

RSpec::Matchers.define :be_encrypted_version do |expected|
  match do |actual|
    MiqPassword.split(actual).first == expected.to_s
  end

  failure_message_for_should do |actual|
    actual_version = MiqPassword.split(actual).first
    actual_version_text = actual_version ? "encrypted with version #{actual_version}" : "not encrypted"
    "expected: #{actual.inspect} to be encrypted with version #{expected} but is #{actual_version_text}"
  end

  failure_message_for_should_not do |actual|
    "expected: #{actual.inspect} not to be encrypted with version #{expected}"
  end

  description do
    "expect to be encrypted with a particular version of miq password (e.g.: 2)"
  end

  def utf8_to_ascii_bytestring(str)
    str.bytes.map(&:chr).join
  end
end
