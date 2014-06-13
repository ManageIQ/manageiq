FactoryGirl.define do
  factory :storage do
    sequence(:name) { |n| "storage_#{n}" }
  end

  factory :storage_vmware, :parent => :storage do
    store_type "VMFS"
  end

  # Factories for perf_capture_timer and perf_capture_gap testing
  factory :storage_target_vmware, :parent => :storage_vmware do
    after(:create) do |x|
      x.perf_capture_enabled = toggle_on_name_seq(x)
    end
  end
end
