FactoryBot.define do
  factory :miq_compare do
    report { nil }
    options { nil }
    initialize_with { new(options, report) }
  end
end
