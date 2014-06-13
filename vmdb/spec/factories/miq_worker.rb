FactoryGirl.define do
  factory :miq_worker do
    pid             Process.pid
  end

  factory :miq_ui_worker, :class => "MiqUiWorker", :parent => :miq_worker
end
