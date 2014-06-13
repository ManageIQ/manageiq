FactoryGirl.define do
  factory :small_environment, :parent => :zone do
    sequence(:name)         { |n| "small_environment_#{n}" }
    sequence(:description)  { |n| "Small Environment #{n}" }
    ext_management_systems  { [FactoryGirl.create(:ems_small_environment)] }

    # Hackery: Due to ntp reload occurring on save, we need to add the servers after saving the zone.
    after(:create) do |z|
      guid   = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(guid)
      MiqServer.my_server_clear_cache
      FactoryGirl.create(:miq_server_master, :guid => guid, :zone => z)
    end
  end

  factory :ems_small_environment, :parent => :ems_vmware do
    hosts        { [FactoryGirl.create(:host_small_environment)] }
    after(:create) do |x|
      x.hosts.each { |h| h.vms.each { |v| v.update_attribute(:ems_id, x.id) } }
    end
  end

  factory :host_small_environment, :parent => :host_with_ref do
    vmm_product  "Workstation"
    vms          { [FactoryGirl.create(:vm_with_ref, :name => "vmtest1"), FactoryGirl.create(:vm_with_ref, :name => "vmtest2")] }
  end
end

# Factory.define :small_environment, :parent => :zone do |z|
#   z.sequence(:name)         { |n| "small_environment_#{n}" }
#   z.sequence(:description)  { |n| "Small Environment #{n}" }
#   z.ext_management_systems  { [FactoryGirl.create(:ems_small_environment)] }

#   # Hackery: Due to ntp reload occurring on save, we need to add the servers after saving the zone.
#   z.after_create { |x| x.miq_servers << FactoryGirl.create(:miq_server_master) }
# end

# Factory.define :ems_small_environment, :parent => :ems_vmware do |e|
#   e.hosts        { [FactoryGirl.create(:host_small_environment)] }
#   e.after_create { |x| x.hosts.each { |h| h.vms.each { |v| v.update_attribute(:ems_id, x.id) } } }
# end

# Factory.define :host_small_environment, :parent => :host_with_ref do |h|
#   h.vmm_product  "Workstation"
#   h.vms          { [FactoryGirl.create(:vm_with_ref, :name => "vmtest1"), FactoryGirl.create(:vm_with_ref, :name => "vmtest2")] }
# end
