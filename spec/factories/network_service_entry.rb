FactoryBot.define do
  factory :network_service_entry do
    sequence(:name) {|n| "network_service_entry_#{seq_padded_for_sorting(n)}"}
    sequence(:description) {|n| "network_service_entry_description_#{seq_padded_for_sorting(n)}"}
    sequence(:ems_ref) {|n| "ems_ref_#{seq_padded_for_sorting(n)}"}
  end

  factory :network_service_entry_nsxt,
          :class  => "ManageIQ::Providers::Nsxt::NetworkManager::NetworkServiceEntry",
          :parent => :network_service_entry
end
