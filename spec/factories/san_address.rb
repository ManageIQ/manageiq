FactoryBot.define do
  factory :fiber_channel_address do
    sequence(:wwpn) { |n| "wwpn_#{seq_padded_for_sorting(n)}" }
  end
end
