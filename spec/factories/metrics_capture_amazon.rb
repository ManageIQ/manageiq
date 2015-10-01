FactoryGirl.define do
  factory :metrics_capture_amazon, :class => "ManageIQ::Providers::Amazon::CloudManager::MetricsCapture" do
    transient do
      target "Amazon"
    end
    initialize_with { new(target) }
  end

  factory :metrics_capture_perf_amazon, :parent => :metrics_capture_amazon do
    ems_ref         "amazon-perf-vm"
  end
end
