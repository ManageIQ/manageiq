RSpec.describe HpcQueue do
  let(:ems) { FactoryBot.create(:ems_hpc) }

  context "::Purging" do
    context ".purge_queue" do
      before do
        EvmSpecHelper.local_miq_server
      end
      let(:purge_time) { (Time.zone.now + 10).round }

      it "submits to the queue" do
        expect(described_class).to receive(:purge_date).and_return(purge_time)
        described_class.purge_timer

        q = MiqQueue.all
        expect(q.length).to eq(1)
        expect(q.first).to have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge_by_date",
          :args        => [purge_time]
        )
      end
    end

    context ".purge" do
      let(:deleted_date) { 6.months.ago }

      before do
        @old_queue        = FactoryBot.create(:hpc_queue, :ext_management_system => ems, :deleted_on => deleted_date - 1.day)
        @purge_date_queue = FactoryBot.create(:hpc_queue, :ext_management_system => ems, :deleted_on => deleted_date)
        @new_queue        = FactoryBot.create(:hpc_queue, :ext_management_system => ems, :deleted_on => deleted_date + 1.day)
        @active_queue     = FactoryBot.create(:hpc_queue, :ext_management_system => ems)
      end

      def assert_unpurged_ids(unpurged_ids)
        expect(described_class.order(:id).pluck(:id)).to eq(Array(unpurged_ids).sort)
      end

      it "purge_date and older" do
        described_class.purge(deleted_date)
        assert_unpurged_ids([@new_queue.id, @active_queue.id])
      end

      it "with a window" do
        described_class.purge(deleted_date, 1)
        assert_unpurged_ids([@new_queue.id, @active_queue.id])
      end

      it "purges associated hpc_queue_nodes" do
        node = FactoryBot.create(:hpc_node, :ext_management_system => ems)
        @old_queue.hpc_nodes << node
        expect(HpcQueueNode.where(:hpc_queue_id => @old_queue.id).count).to eq(1)

        described_class.purge(deleted_date)
        expect(HpcQueueNode.where(:hpc_queue_id => @old_queue.id).count).to eq(0)
      end
    end
  end
end
