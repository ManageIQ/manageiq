FactoryBot.define do
  factory :miq_task do
    status          { "Ok" }
    state           { "Active" }
    sequence(:name) { |n| "task_#{seq_padded_for_sorting(n)}" }
  end

  factory :miq_task_plain, :class => :miq_task
end
