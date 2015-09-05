FactoryGirl.define do
  factory :user do
    # HACK: Due to password_digest callback needing infrastructure to write out
    #       the new password to disk.
    before(:create) do
      MiqRegion.seed
    end

    transient do
      # e.g. "super_administrtor"
      role nil
      # e.g.: "miq_request_approval"
      features nil
    end

    sequence(:userid) { |s| "user#{s}" }
    sequence(:name)   { |s| "Test User #{s}" }

    # encrypted password for "dummy"
    password_digest "$2a$10$FTbGT/y/PQ1HvoOoc1FcyuuTtHzfop/uG/mcEAJLYpzmsUIJcGT7W"

    after :build do |u, e|
      if e.miq_groups.blank? && (e.role || e.features)
        u.miq_groups = [FactoryGirl.create(:miq_group, :features => e.features, :role => e.role)]
      end
    end
  end

  factory :user_with_email, :parent => :user do
    sequence(:email) { |s| "user#{s}@example.com" }
  end

  factory :user_admin, :parent => :user do
    userid          "admin"
    role            "super_administrator"
  end

  factory :user_miq_request_approver, :parent => :user do
    miq_groups { [FactoryGirl.create(:miq_group_miq_request_approver)] }
  end
end
