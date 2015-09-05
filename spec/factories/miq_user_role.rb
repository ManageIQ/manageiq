FactoryGirl.define do
  sequence(:miq_user_role_name) { |n| "UserRole #{seq_padded_for_sorting(n)}" }

  factory :miq_user_role do
    transient do
      # e.g.: miq_request_approval
      features nil
      # e.g.: super_administrator
      role nil
    end

    name { |ur| ur.role ? "EvmRole-#{ur.role}" : generate(:miq_user_role_name) }

    after(:build) do |user, evaluator|
      if evaluator.features.present?
        user.miq_product_features = Array.wrap(evaluator.features).map do |f|
          FactoryGirl.create(:miq_product_feature, :identifier => f)
        end
      end
    end
  end

  factory :miq_user_role_miq_request_approver, :parent => :miq_user_role do
    miq_product_features { [FactoryGirl.create(:miq_product_feature_miq_request_approval)] }
  end
end
