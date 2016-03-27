FactoryGirl.define do
  factory :miq_ems_refresh_core_worker do
    pid { Process.pid }
  end
end
