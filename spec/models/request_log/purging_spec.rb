RSpec.describe RequestLog do
  context "::Purging" do
    let(:settings) do
      {
        :request_logs => {
          :history => {
            :keep_request_logs => "6.months",
            :purge_window_size => 1000
          }
        }
      }
    end

    before do
      stub_settings(settings)
    end

    describe ".purge_by_date" do
      let(:created_on) { 6.months.ago }

      before do
        @old_log        = FactoryBot.create(:request_log, :created_at => created_on - 1.day)
        @purge_date_log = FactoryBot.create(:request_log, :created_at => created_on - 1.second)
        @new_log        = FactoryBot.create(:request_log, :created_at => created_on + 1.day)
      end

      it "purges old request logs" do
        expect(described_class.count).to eq(3)

        described_class.purge_by_date(created_on)

        expect(described_class.count).to eq(1)
        expect(described_class.first.id).to eq(@new_log.id)
      end

      it "purges with a window" do
        callbacks = []

        settings.store_path(:request_logs, :history, :purge_window_size, 1)
        stub_settings(settings)

        expect(described_class.count).to eq(3)

        described_class.purge(created_on) { |count, total| callbacks << [count, total] }

        expect(described_class.count).to eq(1)
        expect(described_class.first.id).to eq(@new_log.id)
        expect(callbacks).to eq([[1, 1], [1, 2]])
      end
    end

    describe ".purge_timer" do
      it "queues the correct purge method" do
        EvmSpecHelper.local_miq_server
        described_class.purge_timer
        q = MiqQueue.first
        expect(q).to have_attributes(:class_name => described_class.name, :method_name => "purge_by_date")
      end
    end
  end
end
