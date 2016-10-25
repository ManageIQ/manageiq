FactoryGirl.define do
  factory :storage do
    sequence(:name) { |n| "storage_#{seq_padded_for_sorting(n)}" }
  end

  factory :storage_vmware, :parent => :storage do
    store_type "VMFS"
  end

  factory :storage_nfs, :parent => :storage do
    store_type "NFS"
  end

  factory :storage_redhat, :parent => :storage_nfs do
    sequence(:ems_ref_obj) { |n| "/api/storagedomains/#{n}" }
  end

  factory :storage_block, :parent => :storage do
    store_type "FCP"
  end

  factory :storage_unknown, :parent => :storage do
    store_type "UNKNOWN"
  end

  # Factories for perf_capture_timer and perf_capture_gap testing
  factory :storage_target_vmware, :parent => :storage_vmware do
    after(:create) do |x|
      x.perf_capture_enabled = toggle_on_name_seq(x)
    end
  end
end
