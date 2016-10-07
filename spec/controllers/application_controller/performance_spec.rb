describe ApplicationController do
  context "#perf_planning_gen_data" do
    it "should not get nil error when submitting up Manual Input data" do
      enterprise = FactoryGirl.create(:miq_enterprise)
      allow(MiqServer).to receive(:my_zone).and_return("default")
      sb = HashWithIndifferentAccess.new
      sb[:planning] = {
        :options => {
          :target_typ => "EmsCluster",
          :vm_mode    => :manual,
          :values     => {
            :cpu => 2
          }
        },
        :vm_opts => {
          :cpu => 2
        }
      }
      controller.instance_variable_set(:@sb, sb)
      allow(controller).to receive(:initiate_wait_for_task)
      controller.send(:perf_planning_gen_data)
    end
  end

  context "#perf_set_or_fix_dates" do
    def push_metric(prov, timestamp, interval = "daily")
      prov.metric_rollups << MetricRollup.create(
        :capture_interval_name => interval,
        :timestamp             => timestamp,
        :time_profile          => TimeProfile.first
      )
    end

    before(:each) do
      allow(MiqServer).to receive(:my_zone).and_return("default")
      ems = FactoryGirl.create(:ems_kubernetes)
      controller.instance_variable_set(:@perf_record, ems)
      push_metric(ems, DateTime.parse('1/1/2016 00:00').utc, "hourly")
      push_metric(ems, DateTime.parse('1/30/2016 23:00').utc, "hourly")
    end

    it "shoud not change the dates" do
      options = {
        :typ         => 'Daily',
        :hourly_date => '1/15/2016',
        :daily_date  => '1/15/2016'
      }
      controller.send(:perf_set_or_fix_dates, options)
      expect(options[:hourly_date]).to eq('1/15/2016')
      expect(options[:daily_date]).to eq('1/15/2016')
    end

    it "should fix empty dates" do
      options = {
        :typ         => 'Daily',
        :hourly_date => ''
      }
      controller.send(:perf_set_or_fix_dates, options)
      expect(options[:hourly_date]).to eq('1/30/2016')
      expect(options[:daily_date]).to eq('1/30/2016')
    end

    it "should fix wrong dates" do
      options = {
        :typ         => 'Daily',
        :hourly_date => '2/15/2016',
        :daily_date  => '2/15/2016'
      }
      controller.send(:perf_set_or_fix_dates, options)
      expect(options[:hourly_date]).to eq('1/30/2016')
      expect(options[:daily_date]).to eq('1/30/2016')
    end
  end
end
