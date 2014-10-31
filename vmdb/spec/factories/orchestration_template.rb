require "digest/md5"

FactoryGirl.define do
  factory :orchestration_template do
    name        "name"
    template    "any template text"
    description "some description"
  end

  factory :orchestration_template_with_stacks, :parent => :orchestration_template do
    after(:create) { |t| t.stacks << FactoryGirl.create(:orchestration_stack) }
  end
end
