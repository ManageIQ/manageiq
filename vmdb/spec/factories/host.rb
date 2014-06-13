FactoryGirl.define do
  factory :host do
    sequence(:name)     { |n| "host_#{n}" }
    sequence(:hostname) { |n| "host_#{n}" }
    vmm_vendor          "vmware"
    ipaddress           "127.0.0.1"
    user_assigned_os    "linux_generic"
    power_state         "on"
  end

  factory :host_with_ref, :parent => :host do
    sequence(:ems_ref)     { |n| "host-#{n}" }
    sequence(:ems_ref_obj) { |n| VimString.new("host-#{n}", "HostSystem", "ManagedObjectReference") }
  end

  factory :host_with_authentication, :parent => :host do
    after(:create) do |x|
      x.authentications = [FactoryGirl.build(:authentication, :resource => x)]
    end
  end

  # Factories for perf_capture_timer and perf_capture_gap testing
  factory :host_target_vmware, :parent => :host do
    after(:create) do |x|
      x.perf_capture_enabled = toggle_on_name_seq(x)
      2.times { x.vms << FactoryGirl.create(:vm_target_vmware) }
    end
  end

  factory :host_with_ipmi, :parent => :host do
    ipmi_address "127.0.0.1"
    mac_address  "aa:bb:cc:dd:ee:ff"
    after(:create) do |x|
      x.authentications = [FactoryGirl.build(:authentication_ipmi, :resource => x)]
    end
  end

  factory :host_with_no_ipmi, :parent => :host do
    ipmi_address "127.0.0.1"
    mac_address  "aa:bb:cc:dd:ee:ff"
    after(:create) do |x|
      x.authentications = [FactoryGirl.build(:authentication, :resource => x)]
    end
  end

  # Type specific subclasses
  factory :host_vmware, :parent => :host, :class => "HostVmware" do
    vmm_vendor "vmware"
  end

  factory :host_vmware_esx, :parent => :host_vmware, :class => "HostVmwareEsx" do
  end

  factory :host_redhat, :parent => :host, :class => "HostRedhat" do
    vmm_vendor "redhat"
  end

  factory :host_microsoft, :parent => :host, :class => "HostMicrosoft" do
    vmm_vendor  "microsoft"
    vmm_product "Hyper-V"
  end

  factory :host_with_default_resource_pool, :parent => :host do
    after(:create) { |h| h.add_child(FactoryGirl.create(:default_resource_pool)) }
  end

  factory :host_with_default_resource_pool_with_vms, :parent => :host do
    after(:create) { |h| h.add_child(FactoryGirl.create(:default_resource_pool_with_vms)) }
  end
end
