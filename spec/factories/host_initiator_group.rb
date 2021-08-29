FactoryBot.define do
  factory :host_initiator_group do
    sequence(:name) { |n| "host_initiator_group_#{seq_padded_for_sorting(n)}" }
  end
end
