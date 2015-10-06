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
end
