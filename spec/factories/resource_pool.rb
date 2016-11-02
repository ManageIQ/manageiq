FactoryGirl.define do
  factory :resource_pool do
    sequence(:name) { |n| "rp_#{seq_padded_for_sorting(n)}" }
  end

  factory :default_resource_pool, :parent => :resource_pool do
    is_default true
  end
end
