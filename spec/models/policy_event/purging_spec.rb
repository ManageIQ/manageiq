RSpec.describe PolicyEvent do
  context "::Purging" do
    context ".purge_timer" do
      before do
        EvmSpecHelper.local_miq_server
      end

      it "with nothing in the queue" do
        described_class.purge_timer

        q = MiqQueue.all
        expect(q.length).to eq(1)
        expect(q.first).to  have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge_by_date"
        )
      end
    end
  end
end
