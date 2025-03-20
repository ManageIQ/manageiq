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
        FactoryBot.create(:miq_report_result, :miq_report_id => 1, :created_on => (6.months + 1.day).to_i.seconds.ago.utc),
        FactoryBot.create(:miq_report_result, :miq_report_id => 1, :created_on => (6.months - 1.day).to_i.seconds.ago.utc)
      ]
      @rr2 = [
        FactoryBot.create(:miq_report_result, :miq_report_id => 2, :created_on => (6.months + 2.days).to_i.seconds.ago.utc),
        FactoryBot.create(:miq_report_result, :miq_report_id => 2, :created_on => (6.months + 1.day).to_i.seconds.ago.utc),
        FactoryBot.create(:miq_report_result, :miq_report_id => 2, :created_on => (6.months - 1.day).to_i.seconds.ago.utc)
      ]
      @rr_orphaned = [
        FactoryBot.create(:miq_report_result, :miq_report_id => nil, :created_on => (6.months - 1.day).to_i.seconds.ago.utc)
      ]
    end

    context "#purge_by_date" do
      before do
        MiqReportResult.all.each do |r|
          r.binary_blob = FactoryBot.create(:binary_blob)
          r.miq_report_result_details << FactoryBot.create(:MiqReportResultDetail)
          r.save!
        end
      end

      it "deletes rows and associated table rows" do
        MiqReportResult.purge_by_date(Time.now + 1.day)

        expect(MiqReportResult.count).to eq 0
        expect(MiqReportResultDetail.count).to eq 0
        expect(BinaryBlob.count).to eq 0
      end

      it "deletes associated records first, leaving parent rows in case of error" do
        initial_count = MiqReportResult.count
        allow(MiqReportResult).to receive(:purge_associated_records).and_raise

        begin
          MiqReportResult.purge_by_date(Time.now + 1.day)
        rescue
          # Ignore the error, we only care that it failed
        end

        expect(MiqReportResult.count).to eq initial_count # parent is kept due to a failure
      end
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
      EvmSpecHelper.local_miq_server

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
        EvmSpecHelper.local_miq_server
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
