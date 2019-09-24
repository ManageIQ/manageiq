FactoryBot.define do
  sequence(:miq_group_description) { |n| "Test Group #{seq_padded_for_sorting(n)}" }

  factory :miq_group do
    transient do
      features { nil }
      role { nil }

      # Temporary: Allows entitlements, a new table, to be invisible to current spec setup code
      # Do NOT use these if possible.
      miq_user_role_id { nil }
      miq_user_role { nil }
    end

    sequence(:sequence)  # don't want to spend time looking these up
    description { |g| g.role ? "EvmGroup-#{g.role}" : generate(:miq_group_description) }

    after :build do |g, e|
      if e.role || e.features || e.miq_user_role_id || e.miq_user_role
        g.entitlement = FactoryBot.create(:entitlement,
                                           :features => e.features,
                                           :role => e.role,
                                           :miq_user_role_id => e.miq_user_role_id,
                                           :miq_user_role => e.miq_user_role)
      end
    end

    trait :system_type do
      group_type { MiqGroup::SYSTEM_GROUP }
    end

    trait :tenant_type do
      group_type { MiqGroup::TENANT_GROUP }
    end

    transient do
      default_tenant { nil }
    end

    trait :in_other_region do
      other_region

      after(:create) do |instance, evaluator|
        instance.tenant = evaluator.default_tenant
      end
    end
  end
end
