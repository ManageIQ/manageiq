require_migration

describe DeleteMiqReplicationWorker do
  migration_context :up do
    let(:miq_worker) { migration_stub(:MiqWorker) }

    it "deletes replication worker instances" do
      miq_worker.create(:type => "MiqWorker")
      miq_worker.create(:type => "MiqReplicationWorker")

      expect(miq_worker.count).to eq(2)

      migrate

      expect(miq_worker.count).to      eq(1)
      expect(miq_worker.first.type).to eq("MiqWorker")
    end
  end
end
