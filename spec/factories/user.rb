FactoryGirl.define do
  factory :user do
    transient do
      # e.g. "super_administrator"
      role nil
      # e.g.: "miq_request_approval"
      features nil
    end

    sequence(:userid) { |s| "user#{s}" }
    sequence(:name)   { |s| "Test User #{s}" }

    # encrypted password for "dummy"
    password_digest "$2a$10$FTbGT/y/PQ1HvoOoc1FcyuuTtHzfop/uG/mcEAJLYpzmsUIJcGT7W"

    after :build do |user, evaluator|
      unless evaluator.user_groups.present?
        if evaluator.role || evaluator.features
          group = UserGroup.find_by_description("EvmGroup-#{evaluator.role}") ||
                  FactoryGirl.create(:user_group,
                                     :features => evaluator.features,
                                     :role     => evaluator.role)
          user.user_groups = [group]
        end
      end
    end
  end

  factory :user_with_email, :parent => :user do
    sequence(:email) { |s| "user#{s}@example.com" }
  end

  factory :user_with_email_and_group, :parent => :user_with_group do
    sequence(:email) { |s| "user#{s}@example.com" }
  end

  factory :user_with_group, :parent => :user do
    user_groups { FactoryGirl.create_list(:user_group, 1) }
  end

  factory :user_admin, :parent => :user do
    role "super_administrator"
  end

  factory :user_miq_request_approver, :parent => :user do
    features "miq_request_approval"
  end
end
