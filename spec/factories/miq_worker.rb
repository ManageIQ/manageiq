FactoryGirl.define do
  factory :miq_worker do
    pid    { rand(99999) }
    status "ready"
  end

  factory :miq_ui_worker, :class => "MiqUiWorker", :parent => :miq_worker
  factory :miq_websocket_worker, :class => "MiqWebsocketWorker", :parent => :miq_worker

  factory :miq_ems_metrics_processor_worker, :class => "MiqEmsMetricsProcessorWorker", :parent => :miq_worker

  factory :miq_ems_refresh_worker,
          :parent => :miq_worker,
          :class  => "ManageIQ::Providers::BaseManager::RefreshWorker"

  factory :ems_refresh_worker_amazon,
          :parent => :miq_ems_refresh_worker,
          :class  => "ManageIQ::Providers::Amazon::CloudManager::RefreshWorker"

  factory :embedded_ansible_worker,
          :parent => :miq_worker,
          :class  => "EmbeddedAnsibleWorker"
end
