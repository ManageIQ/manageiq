FactoryBot.define do
  factory :storage do
    sequence(:name) { |n| "storage_#{seq_padded_for_sorting(n)}" }
  end

  factory :storage_vmware, :parent => :storage do
    store_type { "VMFS" }
    sequence(:ems_ref) { |n| "datastore-#{n}" }
  end

  factory :storage_nfs, :parent => :storage do
    store_type { "NFS" }
  end

  factory :storage_redhat, :parent => :storage_nfs do
    sequence(:ems_ref)             { |n| "/api/storagedomains/#{n}" }
    sequence(:storage_domain_type) { |n| n == 2 ? "iso" : "data" }
  end

  factory :storage_block, :parent => :storage do
    store_type { "FCP" }
  end

  factory :storage_unknown, :parent => :storage do
    store_type { "UNKNOWN" }
  end
end
