describe Metric::CiMixin::Capture do

  before :each do
    _guid, _server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems_openstack = FactoryGirl.create(:ems_openstack, :zone => @zone)
    @vm = FactoryGirl.create(:vm_perf_openstack, :ext_management_system => @ems_openstack)
  end

  before do
    @orig_log = $log
    $log = double.as_null_object
  end

  after do
    $log = @orig_log
  end

  def expected_stats_period_start
    parse_datetime('2013-08-28T11:01:20Z')
  end

  def expected_stats_period_end
    parse_datetime('2013-08-28T12:41:40Z')
  end

  context "#perf_capture_queue('realtime')" do
    def verify_realtime_queue_item(queue_item, expected_start_time = nil)
      expect(queue_item.method_name).to eq "perf_capture_realtime"
      if expected_start_time
        q_start_time = queue_item.args.first
        expect(q_start_time).to be_same_time_as expected_start_time
      end
    end

    def verify_historical_queue_item(queue_item, expected_start_time, expected_end_time)
      expect(queue_item.method_name).to eq "perf_capture_historical"
      q_start_time, q_end_time = queue_item.args
      expect(q_start_time).to be_same_time_as expected_start_time
      expect(q_end_time).to be_same_time_as expected_end_time
    end

    def verify_perf_capture_queue(last_perf_capture_on, total_queue_items)
      Timecop.freeze do
        @vm.last_perf_capture_on = last_perf_capture_on
        @vm.perf_capture_queue("realtime")
        expect(MiqQueue.count).to eq total_queue_items

        # make sure the queue items are in the correct order
        queue_items = MiqQueue.order(:id).to_a

        # first queue item is realtime and only has a start time
        realtime_cut_off = 4.hours.ago.utc.beginning_of_day
        realtime_start_time = realtime_cut_off if last_perf_capture_on.nil? || last_perf_capture_on < realtime_cut_off
        verify_realtime_queue_item(queue_items.shift, realtime_start_time)

        # rest of the queue items should be historical
        if queue_items.any? && realtime_start_time
          interval_start_time = @vm.last_perf_capture_on
          interval_end_time   = interval_start_time + 1.day
          queue_items.reverse.each do |q_item|
            verify_historical_queue_item(q_item, interval_start_time, interval_end_time)

            interval_start_time = interval_end_time
            interval_end_time  += 1.day # if collection threshold is parameterized, this increment should change
            interval_end_time   = realtime_start_time if interval_end_time > realtime_start_time
          end
        end
      end
    end

    it "when last_perf_capture_on is nil (first time)" do
      MiqQueue.delete_all
      Timecop.freeze do
        Timecop.travel(Time.now.end_of_day - 6.hours)
        verify_perf_capture_queue(nil, 1)
        Timecop.travel(Time.now + 20.minutes)
        verify_perf_capture_queue(nil, 1)
      end
    end

    it "when last_perf_capture_on is very old (older than the realtime_cut_off of 4.hours.ago)" do
      MiqQueue.delete_all
      Timecop.freeze do
        Timecop.travel(Time.now.end_of_day - 6.hours)
        verify_perf_capture_queue((10.days + 5.hours + 23.minutes).ago, 11)
      end
    end

    it "when last_perf_capture_on is recent (before the realtime_cut_off of 4.hours.ago)" do
      MiqQueue.delete_all
      Timecop.freeze do
        Timecop.travel(Time.now.end_of_day - 6.hours)
        verify_perf_capture_queue((0.days + 2.hours + 5.minutes).ago, 1)
      end
    end

    it "is able to handle multiple attempts to queue perf_captures and not add new items" do
      MiqQueue.delete_all
      Timecop.freeze do
        # set a specific time of day to avoid sporadic test failures that fall on the exact right time to bump the
        # queue items to 12 instead of 11
        current_time = Time.now.end_of_day - 6.hours
        Timecop.travel(current_time)
        last_perf_capture_on = (10.days + 5.hours + 23.minutes).ago
        verify_perf_capture_queue(last_perf_capture_on, 11)
        Timecop.travel(current_time + 20.minutes)
        verify_perf_capture_queue(last_perf_capture_on, 11)
      end
    end
  end

  context "historical with capture days > 0 and multiple attempts" do
    def verify_perf_capture_queue_historical(last_perf_capture_on, total_queue_items)
      @vm.last_perf_capture_on = last_perf_capture_on
      @vm.perf_capture_queue("historical")
      expect(MiqQueue.count).to eq total_queue_items
    end

    it "when last_perf_capture_on is nil(first time)" do
      MiqQueue.delete_all
      Timecop.freeze do
        allow(Metric::Capture).to receive(:historical_days).and_return(7)
        current_time = Time.now.end_of_day - 6.hours
        Timecop.travel(current_time)
        verify_perf_capture_queue_historical(nil, 8)
        Timecop.travel(current_time + 20.minutes)
        verify_perf_capture_queue_historical(nil, 8)
      end
    end

    it "when last_perf_capture_on is very old" do
      MiqQueue.delete_all
      Timecop.freeze do
        # set a specific time of day to avoid sporadic test failures that fall on the exact right time to bump the
        # queue items to 12 instead of 11
        allow(Metric::Capture).to receive(:historical_days).and_return(7)
        current_time = Time.now.end_of_day - 6.hours
        last_capture_on = (10.days + 5.hours + 23.minutes).ago
        Timecop.travel(current_time)
        verify_perf_capture_queue_historical(last_capture_on, 8)
        Timecop.travel(current_time + 20.minutes)
        verify_perf_capture_queue_historical(last_capture_on, 8)
      end
    end

    it "when last_perf_capture_on is fairly recent" do
      MiqQueue.delete_all
      Timecop.freeze do
        # set a specific time of day to avoid sporadic test failures that fall on the exact right time to bump the
        # queue items to 12 instead of 11
        allow(Metric::Capture).to receive(:historical_days).and_return(7)
        current_time = Time.now.end_of_day - 6.hours
        last_capture_on = (10.days + 5.hours + 23.minutes).ago
        Timecop.travel(current_time)
        verify_perf_capture_queue_historical(last_capture_on, 8)
        Timecop.travel(current_time + 20.minutes)
        verify_perf_capture_queue_historical(last_capture_on, 8)
      end
    end
  end

  def parse_datetime(datetime)
    datetime << "Z" if datetime.size == 19
    Time.parse(datetime).utc
  end

  context "handles archived container entities" do
    it "get the correct queue name and zone from archived container entities" do
      ems = FactoryGirl.create(:ems_openshift, :name => 'OpenShiftProvider')
      group = FactoryGirl.create(:container_group, :name => "group", :ext_management_system => ems)
      container = FactoryGirl.create(:container,
                                     :name                  => "container",
                                     :container_group       => group,
                                     :ext_management_system => ems)
      project = FactoryGirl.create(:container_project,
                                   :name                  => "project",
                                   :ext_management_system => ems)
      container.disconnect_inv
      group.disconnect_inv
      project.disconnect_inv

      expect(container.ems_for_capture_target).to eq ems
      expect(group.ems_for_capture_target).to     eq ems
      expect(project.ems_for_capture_target).to   eq ems

      expect(container.my_zone).to eq ems.my_zone
      expect(group.my_zone).to eq ems.my_zone
      expect(project.my_zone).to eq ems.my_zone
    end
  end
end
