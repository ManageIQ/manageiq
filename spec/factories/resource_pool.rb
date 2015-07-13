FactoryGirl.define do
  factory :resource_pool do
    sequence(:name) { |n| "rp_#{seq_padded_for_sorting(n)}" }
  end

  factory :default_resource_pool, :parent => :resource_pool do
    is_default true
  end

  factory :default_resource_pool_with_vms, :parent => :resource_pool do
    after(:create) do |rp|
      rp.add_child(FactoryGirl.create(:vm_vmware))
    end
  end
end
