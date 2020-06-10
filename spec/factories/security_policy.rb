FactoryBot.define do
  factory :security_policy do
    sequence(:name) {|n| "security_policy_#{seq_padded_for_sorting(n)}"}
    sequence(:description) {|n| "security_policy_description_#{seq_padded_for_sorting(n)}"}
    sequence(:ems_ref) {|n| "ems_ref_#{seq_padded_for_sorting(n)}"}
  end

  factory :security_policy_nsxt,
          :class  => "ManageIQ::Providers::Nsxt::NetworkManager::SecurityPolicy",
          :parent => :security_policy
end
