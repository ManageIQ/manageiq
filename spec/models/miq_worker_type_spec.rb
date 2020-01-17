RSpec.describe MiqWorkerType do
  describe ".seed" do
    before { described_class.seed }

    it "correctly creates records for workers" do
      generic_worker = described_class.find_by(:worker_type => "MiqGenericWorker")
      ui_worker      = described_class.find_by(:worker_type => "MiqUiWorker")

      expect(generic_worker.bundler_groups).to match_array(MiqGenericWorker.bundler_groups)
      expect(generic_worker.kill_priority).to eq(MiqGenericWorker.kill_priority)

      expect(ui_worker.bundler_groups).to match_array(MiqUiWorker.bundler_groups)
      expect(ui_worker.kill_priority).to eq(MiqUiWorker.kill_priority)
    end

    it "removes worker records which no longer exist" do
      old_worker_name = "MiqReplicationWorker"
      described_class.create!(
        :worker_type    => old_worker_name,
        :bundler_groups => [],
        :kill_priority  => 123
      )

      described_class.seed

      expect(described_class.find_by(:worker_type => old_worker_name)).to be_nil
    end
  end
end
