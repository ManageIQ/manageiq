RSpec.describe MiqReportResult do
  context "::Purging" do
    let(:settings) do
      {
        :reporting => {
          :history => {
            :keep_reports      => "6.months",
            :purge_window_size => 100
          }
        }
      }
    end

    before do
      stub_settings(settings)

      @rr1 = [
        FactoryBot.create(:miq_report_result, :miq_report_id => 1, :created_on => (6.months + 1.days).to_i.seconds.ago.utc),
        FactoryBot.create(:miq_report_result, :miq_report_id => 1, :created_on => (6.months - 1.days).to_i.seconds.ago.utc)
      ]
      @rr2 = [
        FactoryBot.create(:miq_report_result, :miq_report_id => 2, :created_on => (6.months + 2.days).to_i.seconds.ago.utc),
        FactoryBot.create(:miq_report_result, :miq_report_id => 2, :created_on => (6.months + 1.days).to_i.seconds.ago.utc),
        FactoryBot.create(:miq_report_result, :miq_report_id => 2, :created_on => (6.months - 1.days).to_i.seconds.ago.utc)
      ]
      @rr_orphaned = [
        FactoryBot.create(:miq_report_result, :miq_report_id => nil, :created_on => (6.months - 1.days).to_i.seconds.ago.utc)
      ]
    end

    context "#purge_mode_and_value" do
      it "with date" do
        settings.store_path(:reporting, :history, :keep_reports, "1.day")
        stub_settings(settings)
        Timecop.freeze(Time.now) do
          expect(described_class.purge_mode_and_value).to eq([:date, 1.day.to_i.seconds.ago.utc])
        end
      end

      it "with count" do
        settings.store_path(:reporting, :history, :keep_reports, 50)
        stub_settings(settings)
        expect(described_class.purge_mode_and_value).to eq([:remaining, 50])
      end
    end

    context "#purge_window_size" do
      it "with value" do
        settings.store_path(:reporting, :history, :purge_window_size, 1000)
        stub_settings(settings)
        Timecop.freeze(Time.now) do
          expect(described_class.purge_window_size).to eq(1000)
        end
      end
    end

    it "#purge_timer" do
      EvmSpecHelper.create_guid_miq_server_zone

      Timecop.freeze(Time.now) do
        described_class.purge_timer

        q = MiqQueue.all
        expect(q.length).to eq(1)
        expect(q.first).to have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge_by_date"
        )

        expect(q.first.args[0]).to be_within(0.1).of 6.months.to_i.seconds.ago.utc
      end
    end

    context "#purge_queue" do
      before do
        EvmSpecHelper.create_guid_miq_server_zone
        described_class.purge_queue(:remaining, 1)
      end

      it "with nothing in the queue" do
        q = MiqQueue.all
        expect(q.length).to eq(1)
        expect(q.first).to have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge_by_remaining",
          :args        => [1]
        )
      end
    end

    context "#purge_count (used by tools - avoid, it is very expensive)" do
      it "by remaining" do
        expect(described_class.purge_count(:remaining, 1)).to eq(3)
      end

      it "by date" do
        expect(described_class.purge_count(:date, 6.months.to_i.seconds.ago.utc)).to eq(3)
      end
    end

    context "#purge" do
      it "by remaining" do
        described_class.purge(:remaining, 1)
        expect(described_class.where(:miq_report_id => 1)).to eq([@rr1.last])
        expect(described_class.where(:miq_report_id => 2)).to eq([@rr2.last])
        expect(described_class.where(:miq_report_id => nil)).to eq(@rr_orphaned)
      end

      it "by date" do
        described_class.purge(:date, 6.months.to_i.seconds.ago.utc)
        expect(described_class.where(:miq_report_id => 1)).to eq([@rr1.last])
        expect(described_class.where(:miq_report_id => 2)).to eq([@rr2.last])
        expect(described_class.where(:miq_report_id => nil)).to eq(@rr_orphaned)
      end
    end
  end
end
