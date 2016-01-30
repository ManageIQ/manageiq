FactoryGirl.define do
  factory :tenant_quota do
    factory :tenant_quota_cpu do
      name :cpu_allocated
      unit "FIXNUM"
      value 16
      warn_value 12
    end
  end
end
