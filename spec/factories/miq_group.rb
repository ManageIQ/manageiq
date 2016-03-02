FactoryGirl.define do
  factory :miq_group do
    transient do
      # e.g. "super_administrator"
      role nil
      # e.g.: "miq_request_approval"
      features nil
    end

    after :build do |miq_group, evaluator|
      if evaluator.role
        miq_group.miq_user_role = MiqUserRole.find_by_name("EvmRole-#{evaluator.role}") ||
                                  FactoryGirl.create(:miq_user_role,
                                                     :features => evaluator.features,
                                                     :role     => evaluator.role)
      elsif evaluator.features.present?
        miq_group.miq_user_role = FactoryGirl.create(:miq_user_role, :features => evaluator.features)
      end
    end

    factory :system_group do
      group_type MiqGroup::SYSTEM_GROUP
    end
  end
end
