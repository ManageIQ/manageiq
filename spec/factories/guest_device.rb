FactoryBot.define do
  factory :guest_device

  factory :guest_device_nic, :parent => :guest_device do
    sequence(:device_name) { |n| "Network Adapter #{seq_padded_for_sorting(n)}" }
    device_type            { "ethernet" }
    controller_type        { "ethernet" }
    sequence(:address)     { |n| mac_from_seq(n) }
  end

  factory :guest_device_nic_with_network, :parent => :guest_device_nic do
    after(:build) do |x|
      x.network = FactoryBot.build(:network, :hardware_id => x.hardware_id)
    end
  end
end
