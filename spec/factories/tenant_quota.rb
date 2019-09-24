FactoryBot.define do
  factory :tenant_quota do
    factory :tenant_quota_cpu do
      name { :cpu_allocated }
      unit { "fixnum" }
      value { 16 }
      warn_value { 12 }
    end

    factory :tenant_quota_mem do
      name { :mem_allocated }
      unit { "bytes" }
      value { 2_147_483_648 } # 2 GB
    end

    factory :tenant_quota_storage do
      name { :storage_allocated }
      unit { "bytes" }
      value { 2_147_483_648 } # 2 GB
    end

    factory :tenant_quota_vms do
      name { :vms_allocated }
      unit { "FIXNUM" }
      value { 2 }
    end

    factory :tenant_quota_templates do
      name { :templates_allocated }
      unit { "FIXNUM" }
      value { 2 }
    end
  end
end
