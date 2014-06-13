class BeSameTimeAs
  attr_reader :actual, :expected

  def initialize(expected)
    @expected = expected
  end

  def matches?(actual)
    @actual = actual
    @actual.round(precision) == @expected.round(precision)
  end

  def failure_message_for_should
    "\nexpected: #{format_time(@expected)},\n     got: #{format_time(@actual)}\n\n(compared using be_same_time_as with precision of #{precision})"
  end

  def failure_message_for_should_not
    "\nexpected different time from #{format_time(@expected)}\n\n(compared using be_same_time_as with precision of #{precision})"
  end

  def description
    "be the same time as #{format_time(@expected)} to #{precision} digits of precision"
  end

  def with_precision(p)
    @precision = p
    self
  end

  def precision
    @precision ||= case ActiveRecord::Base.connection.adapter_name
    when "PostgreSQL"; 5
    else               0
    end
  end

  private

  def format_time(t)
    "#<#{t.class} #{t.iso8601(10)}>"
  end
end

def be_same_time_as(expected)
  BeSameTimeAs.new(expected)
end
