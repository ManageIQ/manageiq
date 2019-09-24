RSpec::Matchers.define :match_string_array_ignorecase do |expected|
  match do |actual|
    expect(expected.map(&:downcase)).to match_array(actual.map(&:downcase))
  end

  description do
    "a case insensitive string array matcher"
  end
end
