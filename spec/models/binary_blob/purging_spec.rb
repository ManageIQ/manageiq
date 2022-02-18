RSpec.describe BinaryBlob do
  let(:purge_time) { 1.month.ago.round }

  context "::Purging" do
    describe ".purge_date" do
      it "returns a date" do
        expect(described_class.purge_date).to be_kind_of(Time)
      end

      it "changes with settings" do
        stub_settings_merge(:binary_blob => {:keep_orphaned => "1.minute"})

        expect(described_class.purge_date).to be_within(1.second).of(60.seconds.ago.utc)
      end
    end

    describe ".purge_by_scope" do
      it "purges all non-resource rows and expired StateVarHash ones" do
        # BinaryBlob with no resource
        binary_blob1 = BinaryBlob.create

        # BinaryBlob with a resource
        report_result = FactoryBot.create(:miq_report_result)
        binary_blob2  = BinaryBlob.create(:resource => report_result)

        # StateVarHash blob that hasn't expired
        binary_blob3 = BinaryBlob.create(:binary => "---\n", :created_at => 1.week.ago.utc)

        # StateVarHash blob that has expired
        binary_blob4 = BinaryBlob.create(:binary => "---\n", :created_at => 2.months.ago.utc)

        expect(described_class.all).to match_array([binary_blob1, binary_blob2, binary_blob3, binary_blob4])
        count = described_class.purge_by_scope(purge_time)
        expect(described_class.all).to match_array([binary_blob1, binary_blob2, binary_blob3])
        expect(count).to eq(1)
      end
    end

    describe ".purge_timer" do
      it "queues the correct purge method" do
        expect(described_class).to receive(:purge_date).and_return(purge_time)
        EvmSpecHelper.local_miq_server
        described_class.purge_timer

        expect(MiqQueue.first).to have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge_by_scope",
          :args        => [purge_time]
        )
      end
    end
  end
end
