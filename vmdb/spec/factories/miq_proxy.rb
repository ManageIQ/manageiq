FactoryGirl.define do
  factory :active_cos_proxy, :class => :MiqProxy do
    sequence(:name)  { |n| "Active MiqProxy #{seq_padded_for_sorting(n)}" }
    last_heartbeat   { Time.now.utc }
    power_state      "on"
  end

  factory :inactive_cos_proxy, :class => :MiqProxy do
    sequence(:name)  { |n| "Inactive MiqProxy #{seq_padded_for_sorting(n)}" }
    last_heartbeat   Time.at(0)
  end
end
