describe Metric::Purging do
  context "::Purging" do
    it "#purge_all_timer" do
      EvmSpecHelper.create_guid_miq_server_zone

      Timecop.freeze(Time.now) do
        described_class.purge_all_timer

        q = MiqQueue.all
        expect(q.length).to eq(3)

        q.each do |qi|
          expect(qi).to have_attributes(
            :class_name  => described_class.name,
            :method_name => "purge"
          )
        end

        modes = q.collect { |qi| qi.args.last }
        expect(modes).to match_array %w(daily hourly realtime)
      end
    end

    context "with data" do
      let(:vm1) { FactoryGirl.create(:vm_vmware) }
      let(:vm2) { FactoryGirl.create(:vm_vmware) }
      let(:host) { FactoryGirl.create(:host) }
      let(:settings) do
        {
          :performance => {
            :history => {
              :keep_daily_performance    => "6.months",
              :keep_hourly_performance   => "6.months",
              :keep_realtime_performance => "4.hours",
              :purge_window_size         => 1000
            }
          }
        }
      end

      before do
        stub_settings(settings)

        @metrics1 = [
          FactoryGirl.create(:metric_rollup_vm_hr, :resource_id => vm1.id, :timestamp => (6.months + 1.days).ago.utc),
          FactoryGirl.create(:metric_rollup_vm_hr, :resource_id => vm1.id, :timestamp => (6.months - 1.days).ago.utc)
        ]
        @metrics2 = [
          FactoryGirl.create(:metric_rollup_vm_hr, :resource_id => vm2.id, :timestamp => (6.months + 2.days).ago.utc),
          FactoryGirl.create(:metric_rollup_vm_hr, :resource_id => vm2.id, :timestamp => (6.months + 1.days).ago.utc),
          FactoryGirl.create(:metric_rollup_vm_hr, :resource_id => vm2.id, :timestamp => (6.months - 1.days).ago.utc)
        ]
      end

      it "#purge_count" do
        expect(described_class.purge_count(6.months.ago, "hourly")).to eq(3)
      end

      context "#purge" do
        it "without block" do
          described_class.purge(6.months.ago, "hourly")
          expect(MetricRollup.where(:resource_id => @metrics1.last.resource_id)).to eq([@metrics1.last])
          expect(MetricRollup.where(:resource_id => @metrics2.last.resource_id)).to eq([@metrics2.last])
        end

        it "with a block" do
          callbacks = []

          # Adjust the window size to force multiple block callbacks
          settings.store_path(:performance, :history, :purge_window_size, 2)
          stub_settings(settings)

          described_class.purge(6.months.ago, "hourly") { |count, total| callbacks << [count, total] }
          expect(MetricRollup.where(:resource_id => @metrics1.last.resource_id)).to eq([@metrics1.last])
          expect(MetricRollup.where(:resource_id => @metrics2.last.resource_id)).to eq([@metrics2.last])

          expect(callbacks).to eq([[2, 2], [1, 3]])
        end
      end
    end
  end
end
