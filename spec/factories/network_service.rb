FactoryBot.define do
  factory :network_service do
    sequence(:name) {|n| "network_service_#{seq_padded_for_sorting(n)}"}
    sequence(:description) {|n| "network_service_description_#{seq_padded_for_sorting(n)}"}
    sequence(:ems_ref) {|n| "ems_ref_#{seq_padded_for_sorting(n)}"}
  end

  factory :network_service_nsxt,
          :class  => "ManageIQ::Providers::Nsxt::NetworkManager::NetworkService",
          :parent => :network_service
end
