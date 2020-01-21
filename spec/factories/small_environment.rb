FactoryBot.define do
  factory :small_environment, :parent => :zone do
    sequence(:name)         { |n| "small_environment_#{seq_padded_for_sorting(n)}" }
    sequence(:description)  { |n| "Small Environment #{seq_padded_for_sorting(n)}" }
    ext_management_systems  { [FactoryBot.create(:ems_small_environment)] }

    # Hackery: Due to ntp reload occurring on save, we need to add the servers after saving the zone.
    after(:create) do |z|
      EvmSpecHelper.local_miq_server(:is_master => true, :zone => z)
    end
  end

  factory :ems_small_environment, :parent => :ems_vmware do
    hosts        { [FactoryBot.create(:host_small_environment)] }
    after(:create) do |x|
      x.hosts.each { |h| h.vms.each { |v| v.update_attribute(:ems_id, x.id) } }
    end
  end

  factory :host_small_environment, :parent => :host_with_ref do
    vmm_product  { "Workstation" }
    vms          { [FactoryBot.create(:vm_with_ref, :name => "vmtest1"), FactoryBot.create(:vm_with_ref, :name => "vmtest2")] }
  end
end
