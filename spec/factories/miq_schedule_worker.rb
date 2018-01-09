FactoryGirl.define do
  factory :miq_schedule_worker, :parent => :miq_worker, :class => "MiqScheduleWorker"
end
