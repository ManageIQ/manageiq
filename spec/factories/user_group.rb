FactoryGirl.define do
  sequence(:user_group_description) { |n| "Test Group #{seq_padded_for_sorting(n)}" }

  factory :user_group do
    transient do
      # e.g. "super_administrator"
      role nil
      # e.g.: "miq_request_approval"
      features nil
    end

    description { |g| g.role ? "EvmGroup-#{g.role}" : generate(:user_group_description) }

    after :build do |user_group, evaluator|
      unless evaluator.miq_group.present?
        if evaluator.role || evaluator.features
          user_group.miq_group = FactoryGirl.create(:miq_group,
                                                      :role     => evaluator.role,
                                                      :features => evaluator.features)
        end
      end
    end
  end
end
