RSpec::Matchers.define :be_same_time_as do |expected|
  match do |actual|
    actual.round(precision) == expected.round(precision)
  end

  failure_message do |actual|
    "\nexpected: #{format_time(expected)},\n     " \
      "got: #{format_time(actual)}\n\n(compared using be_same_time_as with precision of #{precision})"
  end

  failure_message_when_negated do
    "\nexpected different time from #{format_time(expected)}\n\n" \
      "(compared using be_same_time_as with precision of #{precision})"
  end

  description do
    "be the same time as #{format_time(expected)} to #{precision} digits of precision"
  end

  def with_precision(p)
    @precision = p
    self
  end

  def precision
    @precision ||= 5
  end

  private

  def format_time(t)
    "#<#{t.class} #{t.iso8601(10)}>"
  end
end
