FactoryBot.define do
  factory :small_environment, :parent => :zone do
    sequence(:name)         { |n| "small_environment_#{seq_padded_for_sorting(n)}" }
    sequence(:description)  { |n| "Small Environment #{seq_padded_for_sorting(n)}" }

    after(:create) do |z|
      # Hackery: Due to ntp reload occurring on save,
      #          we need to add the servers after saving the zone.
      EvmSpecHelper.local_miq_server(:is_master => true, :zone => z)
      FactoryBot.create_list(:ems_vmware, 1, :zone => z) do |ems|
        FactoryBot.create(:host, :with_ref, :vmm_product => "Workstation", :ext_management_system => ems) do |host|
          FactoryBot.create_list(:vm_with_ref, 2, :ext_management_system => ems, :host => host)
        end
      end
    end
  end
end
