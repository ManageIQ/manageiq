FactoryGirl.define do
  factory :miq_worker do
    pid    { rand(99999) }
    status "ready"
  end

  factory :miq_ui_worker, :class => "MiqUiWorker", :parent => :miq_worker

  factory :miq_ems_metrics_processor_worker, :class => "MiqEmsMetricsProcessorWorker", :parent => :miq_worker
end
