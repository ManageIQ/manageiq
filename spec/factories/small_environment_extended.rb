FactoryGirl.define do
  factory :small_environment_with_storages, :parent => :small_environment do
    after(:create) do |x|
      storages = [FactoryGirl.create(:storage, :name => "storage 1", :store_type => "VMFS"),
                  FactoryGirl.create(:storage, :name => "storage 2", :store_type => "VMFS")]

      ems  = x.ext_management_systems.first
      host = ems.hosts.first
      [ems, host].each { |ci| storages.each { |s| ci.storages << s } }

      ems.vms.each_with_index do |vm, idx|
        vm.update_attribute(:storage_id, storages[idx].id)
        vm.storages << storages[idx]
      end
    end
  end
end
