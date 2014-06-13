RSpec::Matchers.define :have_same_elements do |a1|
  match do |a2|
    [:select, :inject, :size].each do |m|
      [a1, a2].each {|a| return false unless a.respond_to?(m) }
    end

    a1h = a1.inject({}) { |h,e| h[e] = a1.select { |i| i == e }.size; h }
    a2h = a2.inject({}) { |h,e| h[e] = a2.select { |i| i == e }.size; h }

    a1h == a2h
  end

  failure_message_for_should do |a2|
    "expected: #{a1.inspect},\n     got: #{a2.inspect} (using have_same_elements)"
  end

  failure_message_for_should_not do |a2|
    "expected different elements in #{a1.inspect} (using have_same_elements)"
  end

  description do
    "expect the same elements (in any order) in both arrays"
  end
end
