FactoryBot.define do
  factory :host_initiator do
    sequence(:name) { |n| "host_initiator_#{seq_padded_for_sorting(n)}" }
    after(:create) do |x|
      FactoryBot.create(:fiber_channel_address, :owner => x)
    end
  end
end
