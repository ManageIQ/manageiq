FactoryBot.define do
  factory :openscap_result_skip_callback, :class => OpenscapResult do
    # This callback can be very annoying and handicaping in tests
    after(:build) { |r| r.class.skip_callback(:save, :before, :create_rule_results, :raise => false) }
  end

  factory :openscap_result
end
