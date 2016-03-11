FactoryGirl.define do
  sequence(:user_group_description) { |n| "Test Group #{seq_padded_for_sorting(n)}" }

  factory :user_group do
    transient do
      # e.g. "super_administrator"
      role nil
      # e.g.: "miq_request_approval"
      features nil
    end

    miq_group do
      FactoryGirl.create(:miq_group,
                         :role     => role,
                         :features => features)
    end
    description { |g| g.role ? "EvmGroup-#{g.role}" : generate(:user_group_description) }
  end
end
