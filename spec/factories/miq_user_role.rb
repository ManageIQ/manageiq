FactoryGirl.define do
  factory :miq_user_role do
    name "Test Role"
  end

  factory :miq_user_role_miq_request_approver, :parent => :miq_user_role do
    sequence(:name) { |n| "Request Approver #{seq_padded_for_sorting(n)}" }

    miq_product_features { [FactoryGirl.create(:miq_product_feature_miq_request_approval)] }
  end
end
