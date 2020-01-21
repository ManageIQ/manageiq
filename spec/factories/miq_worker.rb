FactoryBot.define do
  factory :miq_worker do
    pid    { rand(99999) }
    status { "ready" }
  end

  factory :miq_generic_worker, :class => "MiqGenericWorker", :parent => :miq_worker
  factory :miq_ui_worker, :class => "MiqUiWorker", :parent => :miq_worker
  factory :miq_schedule_worker, :parent => :miq_worker, :class => "MiqScheduleWorker"
  factory :miq_remote_console_worker, :class => "MiqRemoteConsoleWorker", :parent => :miq_worker

  factory :miq_ems_metrics_processor_worker, :class => "MiqEmsMetricsProcessorWorker", :parent => :miq_worker

  factory :miq_ems_metrics_collector_worker,
          :class  => "ManageIQ::Providers::BaseManager::MetricsCollectorWorker",
          :parent => :miq_worker

  factory :miq_ems_refresh_worker,
          :parent => :miq_worker,
          :class  => "ManageIQ::Providers::BaseManager::RefreshWorker"

  factory :ems_refresh_worker_amazon,
          :parent => :miq_ems_refresh_worker,
          :class  => "ManageIQ::Providers::Amazon::CloudManager::RefreshWorker"
end
