RSpec.describe Compliance do
  context "::Purging" do
    context ".purge_queue" do
      before do
        EvmSpecHelper.create_guid_miq_server_zone
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
        @old_compliance        = FactoryBot.create(:compliance, :timestamp => deleted_date - 1.day)
        @old_compliance_detail = FactoryBot.create(:compliance_detail, :compliance_id => @old_compliance.id)
        @purge_date_compliance = FactoryBot.create(:compliance, :timestamp => deleted_date)
        @new_compliance        = FactoryBot.create(:compliance, :timestamp => deleted_date + 1.day)
      end

      def assert_unpurged_ids(unpurged_ids)
        expect(described_class.order(:id).pluck(:id)).to eq(Array(unpurged_ids).sort)
      end

      def assert_purged_associated_records
        expect(ComplianceDetail.count).to eq(0)
      end

      it "purge_date and older" do
        described_class.purge(deleted_date)

        assert_unpurged_ids(@new_compliance.id)
        assert_purged_associated_records
      end

      it "with a window" do
        described_class.purge(deleted_date, 1)
        assert_unpurged_ids(@new_compliance.id)
      end
    end
  end
end
