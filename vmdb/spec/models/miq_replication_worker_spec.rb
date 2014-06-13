require "spec_helper"

describe MiqReplicationWorker do
  context "#check_status" do
    def should_handle_check_status(rr_pending_count, rr_pending_last_id, expected_status)
      RrPendingChange.stub(:count).and_return(rr_pending_count)
      RrPendingChange.stub(:last_id).and_return(rr_pending_last_id)

      MiqReplicationWorker.check_status.should == expected_status

      db = MiqDatabase.first
      db.last_replication_count.should == rr_pending_count
      db.last_replication_id.should    == rr_pending_last_id
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
