FactoryGirl.define do
  sequence(:miq_group_description) { |n| "Test Group #{seq_padded_for_sorting(n)}" }

  factory :miq_group do
    transient do
      features nil
      role nil
    end

    guid { MiqUUID.new_guid }
    sequence(:sequence)  # don't want to spend time looking these up
    description { |g| g.role ? "EvmGroup-#{g.role}" : generate(:miq_group_description) }

    after :build do |g, e|
      if e.features.present? || e.role
        g.miq_user_role = FactoryGirl.create(:miq_user_role, :features => e.features, :role => e.role)
      end
    end

    factory :system_group do
      group_type "system" # dont want to reference class from factory MiqGroup::SYSTEM_GROUP
    end
  end
end
