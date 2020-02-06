RSpec.describe EventStream do
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

    context ".purge_date" do
      it "using '3.month' syntax" do
        stub_settings(:event_streams => {:history => {:keep_events => "3.months"}})

        # Exposes 3.months.seconds.ago.utc != 3.months.ago.utc
        expect(described_class.purge_date).to be_within(2.days).of(3.months.ago.utc)
      end

      it "defaults to 6 months" do
        stub_settings(:event_streams => {:history => {:keep_events => nil}})
        expect(described_class.purge_date).to be_within(1.day).of(6.months.ago.utc)
      end
    end

    context ".purge" do
      let(:purge_date) { 2.weeks.ago }

      before do
        @old_event        = FactoryBot.create(:ems_event, :timestamp => purge_date - 1.day)
        @purge_date_event = FactoryBot.create(:ems_event, :timestamp => purge_date)
        @new_event        = FactoryBot.create(:ems_event, :timestamp => purge_date + 1.day)
      end

      def assert_unpurged_ids(unpurged_ids)
        expect(described_class.order(:id).pluck(:id)).to eq(Array(unpurged_ids).sort)
      end

      it "purge_date and older" do
        described_class.purge(purge_date)
        assert_unpurged_ids(@new_event.id)
      end

      it "with a window" do
        described_class.purge(purge_date, 1)
        assert_unpurged_ids(@new_event.id)
      end
    end
  end
end
