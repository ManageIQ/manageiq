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
          f.kind_of?(MiqProductFeature) ? f : FactoryGirl.create(:miq_product_feature, :identifier => f)
        end
      end
    end
  end
end
