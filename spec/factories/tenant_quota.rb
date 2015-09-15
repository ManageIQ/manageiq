FactoryGirl.define do
  factory :tenant_quota do
    factory :tenant_quota_cpu do
      name :cpu_allocated
      unit "mhz"
      value 4096
    end
  end
end
