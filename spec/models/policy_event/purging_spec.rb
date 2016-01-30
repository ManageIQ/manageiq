describe PolicyEvent do
  context "::Purging" do
    context ".purge_queue" do
      before do
        EvmSpecHelper.create_guid_miq_server_zone
      end

      it "with nothing in the queue" do
        described_class.purge_queue

        q = MiqQueue.all
        expect(q.length).to eq(1)
        expect(q.first).to  have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge"
        )
      end

      it "with item already in the queue" do
        described_class.purge_queue
        described_class.purge_queue

        q = MiqQueue.all
        expect(q.length).to eq(1)
        expect(q.first).to  have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge"
        )
      end
    end
  end
end
