FactoryBot.define do
  factory :lan do
    sequence(:name) { |n| "Lan #{seq_padded_for_sorting(n)}" }
  end
end
