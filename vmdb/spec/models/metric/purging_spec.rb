require "spec_helper"

describe Metric::Purging do
  context "::Purging" do
    it "#purge_all_timer" do
      EvmSpecHelper.create_guid_miq_server_zone

      Timecop.freeze(Time.now) do
        described_class.purge_all_timer

        q = MiqQueue.all
        q.length.should == 3

        q.each do |qi|
          qi.should have_attributes(
            :class_name  => described_class.name,
            :method_name => "purge"
          )
        end

        modes = q.collect { |qi| qi.args.last }
        modes.should match_array %w(daily hourly realtime)
      end
    end

    context "with data" do
      before(:each) do
        @vmdb_config = {
          :performance => {
            :history => {
              :keep_daily_performance    => "6.months",
              :keep_hourly_performance   => "6.months",
              :keep_realtime_performance => "4.hours",
              :purge_window_size         => 1000
            }
          }
        }
        VMDB::Config.any_instance.stub(:config).and_return(@vmdb_config)

        @metrics1 = [
          FactoryGirl.create(:metric_rollup_vm_hr, :resource_id => 1, :timestamp => (6.months + 1.days).ago.utc),
          FactoryGirl.create(:metric_rollup_vm_hr, :resource_id => 1, :timestamp => (6.months - 1.days).ago.utc)
        ]
        @metrics2 = [
          FactoryGirl.create(:metric_rollup_vm_hr, :resource_id => 2, :timestamp => (6.months + 2.days).ago.utc),
          FactoryGirl.create(:metric_rollup_vm_hr, :resource_id => 2, :timestamp => (6.months + 1.days).ago.utc),
          FactoryGirl.create(:metric_rollup_vm_hr, :resource_id => 2, :timestamp => (6.months - 1.days).ago.utc)
        ]
      end

      it "#purge_count" do
        described_class.purge_count(6.months.ago, "hourly").should == 3
      end

      context "#purge" do
        it "without block" do
          described_class.purge(6.months.ago, "hourly")
          MetricRollup.where(:resource_id => 1).should == [@metrics1.last]
          MetricRollup.where(:resource_id => 2).should == [@metrics2.last]
        end

        it "with a block" do
          callbacks = []
          # Adjust the window size to force multiple block callbacks
          @vmdb_config.store_path(:performance, :history, :purge_window_size, 2)

          described_class.purge(6.months.ago, "hourly") { |count, total| callbacks << [count, total] }
          MetricRollup.where(:resource_id => 1).should == [@metrics1.last]
          MetricRollup.where(:resource_id => 2).should == [@metrics2.last]

          callbacks.should == [[2, 2], [1, 3]]
        end
      end
    end
  end
end
