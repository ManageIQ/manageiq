describe MiqReplicationWorker do
  context "#check_status" do
    def should_handle_check_status(rr_pending_count, rr_pending_last_id, expected_status)
      allow(RrPendingChange).to receive(:count).and_return(rr_pending_count)
      allow(RrPendingChange).to receive(:last_id).and_return(rr_pending_last_id)

      expect(MiqReplicationWorker.check_status).to eq(expected_status)

      db = MiqDatabase.first
      expect(db.last_replication_count).to eq(rr_pending_count)
      expect(db.last_replication_id).to eq(rr_pending_last_id)
    end

    before(:each) do
      MiqDatabase.seed
    end

    context "on initial check" do
      it "not yet started replicating" do
        should_handle_check_status(0, 0, [0, 0, 0])
      end

      it "without records" do
        should_handle_check_status(0, 1, [0, 0, 0])
      end

      it "with records" do
        should_handle_check_status(2, 5, [2, 2, 0])
      end
    end

    context "on subsequent check" do
      before(:each) do
        MiqDatabase.first.update_attributes(:last_replication_count => 1, :last_replication_id => 2)
      end

      it "with added records" do
        should_handle_check_status(2, 3, [2, 1, 0])
      end

      it "with deleted records" do
        should_handle_check_status(0, 2, [0, 0, 1])
      end

      it "with added and deleted records" do
        should_handle_check_status(2, 5, [2, 3, 2])
      end

      it "with no records left" do
        should_handle_check_status(0, 5, [0, 3, 4])
      end
    end
  end
end
