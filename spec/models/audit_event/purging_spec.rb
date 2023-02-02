RSpec.describe AuditEvent do
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
          :method_name => "purge_by_scope",
          :args        => [purge_time]
        )
      end
    end

    context ".purge" do
      let(:created_on) { 6.months.ago }

      before do
        defaults = {:event => "login", :status => "success", :severity => "info", :message => "all good"}
        @old_audit_event        = FactoryBot.create(:audit_event, defaults.merge(:created_on => created_on - 1.day))
        @purge_date_audit_event = FactoryBot.create(:audit_event, defaults.merge(:created_on => created_on - 1.second))
        @new_audit_event        = FactoryBot.create(:audit_event, defaults.merge(:created_on => created_on + 1.day))
      end

      def assert_unpurged_ids(unpurged_ids)
        expect(described_class.order(:id).pluck(:id)).to eq(Array(unpurged_ids).sort)
      end

      it "purge_date and older" do
        described_class.purge(created_on)
        assert_unpurged_ids(@new_audit_event.id)
        expect(described_class.count).to eq(1)
      end

      it "with a window" do
        described_class.purge(created_on, 1)
        assert_unpurged_ids(@new_audit_event.id)
        expect(described_class.count).to eq(1)
      end
    end
  end
end
