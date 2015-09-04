require "spec_helper"

describe ManageIQ::Providers::Openstack::CloudManager do
  describe ".metrics_collect_queue_name" do
    it "returns the correct queue name" do
      worker_queue = ManageIQ::Providers::Openstack::CloudManager::MetricsCollectorWorker.default_queue_name
      expect(described_class.metrics_collect_queue_name).to eq(worker_queue)
    end
  end
end
