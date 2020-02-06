RSpec.describe Metric::Purging do
  let(:settings) do
    {
      :performance => {
        :history => {
          :keep_daily_performance    => "6.months",
          :keep_hourly_performance   => "6.months",
          :keep_realtime_performance => "4.hours",
          :purge_window_size         => 1000,
          :queue_timeout             => "20.minutes"
        }
      }
    }
  end

  before do
    stub_settings(settings)
  end

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
            :msg_timeout => 1200
          )
        end

        modes = q.collect { |qi| qi[:method_name] }
        expect(modes).to match_array %w(purge_daily purge_hourly purge_realtime)
      end
    end

    context "with data" do
      let(:vm1) { FactoryBot.create(:vm_vmware) }
      let(:vm2) { FactoryBot.create(:vm_vmware) }

      before do
        @metrics1 = [
          FactoryBot.create(:metric_rollup_vm_hr, :resource_id => vm1.id, :timestamp => (6.months + 1.days).ago.utc),
          FactoryBot.create(:metric_rollup_vm_hr, :resource_id => vm1.id, :timestamp => (6.months - 1.days).ago.utc)
        ]
        @metrics2 = [
          FactoryBot.create(:metric_rollup_vm_hr, :resource_id => vm2.id, :timestamp => (6.months + 2.days).ago.utc),
          FactoryBot.create(:metric_rollup_vm_hr, :resource_id => vm2.id, :timestamp => (6.months + 1.days).ago.utc),
          FactoryBot.create(:metric_rollup_vm_hr, :resource_id => vm2.id, :timestamp => (6.months - 1.days).ago.utc)
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

  context "#purge_realtime" do
    before { EvmSpecHelper.create_guid_miq_server_zone }
    let(:vm1) { FactoryBot.create(:vm_vmware) }

    it "deletes mid day" do
      Timecop.freeze('2018-02-01T09:12:00Z') do
        (0..16).each do |hours|
          FactoryBot.create(:metric_vm_rt, :resource_id => vm1.id, :timestamp => (hours.hours.ago + 1.minute))
        end
        expect(Metric.count).to eq(17)
        # keep metric for 05:13 - 09:13
        # note: old metrics will delete metrics at 09:14..09:59 - the new metrics will keep those
        described_class.purge_realtime(4.hours.ago)
        expect(Metric.all.map { |metric| metric.timestamp.hour }.sort).to eq [5, 6, 7, 8, 9]
        expect(Metric.count).to eq(5)
      end
    end

    it "deletes just after midnight" do
      Timecop.freeze('2018-02-01T02:12:00Z') do
        (0..16).each do |hours|
          FactoryBot.create(:metric_vm_rt, :resource_id => vm1.id, :timestamp => (hours.hours.ago + 1.minute))
        end
        expect(Metric.count).to eq(17)
        # keep metric for 22:13 - 02:13
        described_class.purge_realtime(4.hours.ago)
        expect(Metric.all.map { |metric| metric.timestamp.hour }.sort).to eq [0, 1, 2, 22, 23]
        expect(Metric.count).to eq(5)
      end
    end

    it "deletes just after new years" do
      EvmSpecHelper.create_guid_miq_server_zone

      Timecop.freeze('2018-01-01T02:12:00Z') do
        (0..16).each do |hours|
          FactoryBot.create(:metric_vm_rt, :resource_id => vm1.id, :timestamp => (hours.hours.ago + 1.minute))
        end
        expect(Metric.count).to eq(17)
        # keep metric for 22:13 - 02:13
        described_class.purge_realtime(4.hours.ago)
        expect(Metric.all.map { |metric| metric.timestamp.hour }.sort).to eq [0, 1, 2, 22, 23]
        expect(Metric.count).to eq(5)
      end
    end

    it "deletes just after daylight savings (spring forward)" do
      EvmSpecHelper.create_guid_miq_server_zone
      Timecop.freeze('2017-03-12T08:12:00Z') do # 2:00am+05 EST is time of change
        # this is overkill. since we prune every 21 minutes, there will only be ~1 table with data
        (0..16).each do |hours|
          FactoryBot.create(:metric_vm_rt, :resource_id => vm1.id, :timestamp => (hours.hours.ago + 1.minute))
        end
        expect(Metric.count).to eq(17)
        # keep metric for 04:13 - 08:13
        described_class.purge_realtime(4.hours.ago)
        expect(Metric.all.map { |metric| metric.timestamp.hour }.sort).to eq [4, 5, 6, 7, 8]
        expect(Metric.count).to eq(5)
      end
    end

    it "deletes just after daylight savings (fallback)" do
      EvmSpecHelper.create_guid_miq_server_zone
      Timecop.freeze('2017-11-05T08:12:00Z') do # 2:00am+05 EST is time of change
        # this is overkill. since we prune every 21 minutes, there will only be ~1 table with data
        (0..16).each do |hours|
          FactoryBot.create(:metric_vm_rt, :resource_id => vm1.id, :timestamp => (hours.hours.ago + 1.minute))
        end
        expect(Metric.count).to eq(17)
        # keep metric for 04:13 - 08:13
        described_class.purge_realtime(4.hours.ago)
        expect(Metric.all.map { |metric| metric.timestamp.hour }.sort).to eq [4, 5, 6, 7, 8]
        expect(Metric.count).to eq(5)
      end
    end

    context "with 8 hour retention" do
      # since the window duration is passed into the queue / this method, this config change will not matter
      let(:settings) do
        {
          :performance => {
            :history => {
              :keep_realtime_performance => "8.hours",
              :purge_window_size         => 10,
            }
          }
        }
      end

      it "deletes just after midnight" do
        Timecop.freeze('2018-02-01T02:12:00Z') do
          (0..23).each do |hours|
            FactoryBot.create(:metric_vm_rt, :resource_id => vm1.id, :timestamp => (hours.hours.ago + 1.minute))
          end
          expect(Metric.count).to eq(24)
          # keep metric for 18:13 - 02:13
          described_class.purge_realtime(8.hours.ago)
          expect(Metric.all.map { |metric| metric.timestamp.hour }.sort).to eq [0, 1, 2, 18, 19, 20, 21, 22, 23]
          expect(Metric.count).to eq(9)
        end
      end
    end
  end
end
