FactoryGirl.define do
  factory :miq_product_feature do
  end

  factory :miq_product_feature_everything, :parent => :miq_product_feature do
    identifier   "everything"
    name         "Everything"
    description  "Access to Everything"
    protected    false
    feature_type "node"
  end

  factory :miq_product_feature_miq_request_approval, :parent => :miq_product_feature do
    identifier   "miq_request_approval"
    name         "Approve and Deny"
    description  "Approve and Deny Requests"
    protected    false
    feature_type "control"
  end
end
