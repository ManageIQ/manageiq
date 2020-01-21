FactoryBot.define do
  factory :user do
    transient do
      # e.g. "super_administrtor"
      role { nil }
      # e.g.: "miq_request_approval"
      features { nil }
      tenant { Tenant.seed }
    end

    sequence(:userid) { |s| "user#{s}" }
    sequence(:name)   { |s| "Test User #{s}" }

    # encrypted password for "dummy"
    password_digest { "$2a$10$FTbGT/y/PQ1HvoOoc1FcyuuTtHzfop/uG/mcEAJLYpzmsUIJcGT7W" }

    after :build do |u, e|
      if e.miq_groups.blank? && (e.role || e.features)
        u.miq_groups = [
          (e.role && MiqGroup.find_by(:description => "EvmGroup-#{e.role}")) ||
            FactoryBot.create(:miq_group, :features => e.features, :role => e.role, :tenant => e.tenant)
        ]
      end
    end

    trait :with_miq_edit_features do
      features { %w(
        miq_ae_class_edit
        miq_ae_domain_edit
        miq_ae_class_copy
        miq_ae_instance_copy
        miq_ae_method_copy
        miq_ae_namespace_edit
      ) }
    end
  end

  factory :user_with_email, :parent => :user do
    sequence(:email) { |s| "user#{s}@example.com" }
  end

  factory :user_with_email_and_group, :parent => :user_with_group do
    sequence(:email) { |s| "user#{s}@example.com" }
  end

  factory :user_with_group, :parent => :user do
    miq_groups { FactoryBot.build_list(:miq_group, 1, :tenant => tenant) }
  end

  factory :user_admin, :parent => :user do
    role { "super_administrator" }
  end

  factory :user_miq_request_approver, :parent => :user do
    features { "miq_request_approval" }
  end
end
