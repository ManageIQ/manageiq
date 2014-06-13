FactoryGirl.define do
  factory :miq_task do
    status          "Ok"
    state           "Active"
    sequence(:name) { |n| "task_#{n}" }
  end

  factory :miq_task_plain, :class => :miq_task do
  end
end
