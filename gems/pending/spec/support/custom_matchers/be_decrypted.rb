# see also be_encrypted
# decryption doesn't always join unicode characters together correctly
# this matcher handles that case
RSpec::Matchers.define :be_decrypted do |expected|
  match do |actual|
    actual == expected
  end

  failure_message do |actual|
    "expected: #{actual.inspect} to be decrypted to #{expected}"
  end

  failure_message_when_negated do |actual|
    "expected: #{actual.inspect} to not equal #{expected}"
  end

  description do
    "expect to be decrypted from a string (fixing utf8 encoding issues)"
  end
end
