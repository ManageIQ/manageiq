FactoryGirl.define do
  factory :miq_schedule_validation, :class => :MiqSchedule do
    sequence(:name)     { |n| "schedule_#{seq_padded_for_sorting(n)}" }
    description         "test"
    towhat              "MiqReport"
    run_at              {}
    sched_action        {}
  end

  factory :miq_schedule do
    run_at = {:start_time   => "2010-07-08 04:10:00 Z", :interval => { :unit => "daily", :value => "1"  } }
    sched_action = {:method => "test"}
    sequence(:name)     { |n| "schedule_#{seq_padded_for_sorting(n)}" }
    description         "test"
    towhat              "MiqReport"
    run_at              run_at
    sched_action        sched_action
  end
end
