describe ManageIQ::Providers::BaseManager::MetricsCapture do
  include Spec::Support::MetricHelper

  subject { described_class.new(nil, ems) }
  let(:miq_server) { EvmSpecHelper.local_miq_server }
  let(:ems) { FactoryBot.create(:ems_vmware, :zone => miq_server.zone) }

  context ".perf_capture_health_check" do
    let(:vm) { FactoryBot.create(:vm_perf, :ext_management_system => ems) }
    let(:vm2) { FactoryBot.create(:vm_perf, :ext_management_system => ems) }

    it "should queue up realtime capture for vm" do
      subject.queue_captures([vm, vm2], {})
      expect(MiqQueue.count).to eq(2)

      expect(subject._log).to receive(:info).with(/2 "realtime" captures on the queue.*oldest:.*recent:/)
      expect(subject._log).to receive(:info).with(/0 "hourly" captures on the queue/)
      expect(subject._log).to receive(:info).with(/0 "historical" captures on the queue/)
      subject.send(:perf_capture_health_check)
    end
  end

  describe ".perf_capture_now" do
    context "with enabled and disabled targets" do
      before do
        MiqRegion.seed
        storages = FactoryBot.create_list(:storage_target_vmware, 2)
        clusters = FactoryBot.create_list(:cluster_target, 2)
        ems.ems_clusters = clusters

        6.times do |n|
          host = FactoryBot.create(:host_target_vmware, :ext_management_system => ems)
          ems.hosts << host

          clusters[n / 2].hosts << host if n < 4
          host.storages << storages[n / 3]
        end

        MiqQueue.delete_all
      end

      context "executing perf_capture_gap" do
        before do
          t = Time.now.utc
          Metric::Capture.perf_capture_gap(t - 7.days, t - 5.days, nil, ems.id)
        end

        it "should queue up enabled targets for historical" do
          expect(MiqQueue.count).to eq(10)

          expected_targets = Metric::Targets.capture_ems_targets(ems.reload, :exclude_storages => true)
          expected = expected_targets.flat_map { |t| [[t, "historical"]] * 2 } # Vm, Host, Host, Vm, Host

          selected = queue_intervals(MiqQueue.all)

          expect(selected).to match_array(expected)
        end
      end
    end
  end

  describe ".perf_capture_now?" do
    before do
      stub_performance_settings(
        :capture_threshold_with_alerts => {:host => "2.minutes"},
        :capture_threshold             => {:host => "10.minutes"}
      )
    end

    let(:target) { FactoryBot.build(:host_vmware, :ext_management_system => ems) }

    context "with a host with alerts" do
      before do
        allow(MiqAlert).to receive(:target_needs_realtime_capture?).with(target).and_return(true)
      end

      it "captures if the target has never been captured" do
        target.last_perf_capture_on = nil
        expect(subject.send(:perf_capture_now?, target)).to eq(true)
      end

      it "does not capture if the target has been captured very recenlty" do
        target.last_perf_capture_on = 1.minute.ago
        expect(subject.send(:perf_capture_now?, target)).to eq(false)
      end

      it "captures if the target has been captured recently (but after realtime minimum)" do
        target.last_perf_capture_on = 5.minutes.ago
        expect(subject.send(:perf_capture_now?, target)).to eq(true)
      end

      it "captures if the target hasn't been captured in a long while" do
        target.last_perf_capture_on = 15.minutes.ago
        expect(subject.send(:perf_capture_now?, target)).to eq(true)
      end
    end

    context "with an alertless host" do
      before do
        allow(MiqAlert).to receive(:target_needs_realtime_capture?).with(target).and_return(false)
      end

      it "captures if the target has never been captured" do
        target.last_perf_capture_on = nil
        expect(subject.send(:perf_capture_now?, target)).to eq(true)
      end

      it "does not captures if the target has been captured very recently" do
        target.last_perf_capture_on = 1.minute.ago
        expect(subject.send(:perf_capture_now?, target)).to eq(false)
      end

      it "does not captures if the target has been captured recently (but after realtime minimum)" do
        target.last_perf_capture_on = 5.minutes.ago
        expect(subject.send(:perf_capture_now?, target)).to eq(false)
      end

      it "captures if the target hasn't been captured in a long while" do
        target.last_perf_capture_on = 15.minutes.ago
        expect(subject.send(:perf_capture_now?, target)).to eq(true)
      end
    end
  end

  describe ".perf_capture_queue" do
    before do
      MiqRegion.seed
    end

    let(:host) { FactoryBot.create(:host_target_vmware, :ext_management_system => ems).tap { MiqQueue.delete_all } }
    let(:vm) { host.vms.first }

    context "for queue prioritization" do
      it "should queue up realtime capture for vm" do
        vm.perf_capture_realtime_now
        expect(MiqQueue.count).to eq(1)

        msg = MiqQueue.first
        expect(msg.priority).to eq(MiqQueue::HIGH_PRIORITY)
        expect(msg.instance_id).to eq(vm.id)
        expect(msg.class_name).to eq("ManageIQ::Providers::Vmware::InfraManager::Vm")
      end

      it "should raise the priority of the existing queue item" do
        vm.perf_capture_realtime_now
        MiqQueue.first.update_attribute(:priority, MiqQueue::NORMAL_PRIORITY)
        vm.perf_capture_realtime_now

        expect(MiqQueue.count).to eq(1)
        expect(MiqQueue.first.priority).to eq(MiqQueue::HIGH_PRIORITY)
      end

      it "should not lower the priority of the existing queue item" do
        vm.perf_capture_realtime_now
        MiqQueue.first.update_attribute(:priority, MiqQueue::MAX_PRIORITY)
        vm.perf_capture_realtime_now

        expect(MiqQueue.count).to eq(1)
        expect(MiqQueue.first.priority).to eq(MiqQueue::MAX_PRIORITY)
      end
    end
  end

  describe "#perf_capture_queue('realtime')" do
    let!(:ems) { FactoryBot.create(:ems_openstack, :zone => miq_server.zone) }
    let(:vm) { FactoryBot.create(:vm_perf_openstack, :ext_management_system => ems) }

    def verify_realtime_queue_item(queue_item, expected_start_time = nil)
      expect(queue_item.method_name).to eq "perf_capture_realtime"
      if expected_start_time
        q_start_time = queue_item.args.first
        expect(q_start_time).to be_within(0.00001).of expected_start_time
      end
    end

    def verify_historical_queue_item(queue_item, expected_start_time, expected_end_time)
      expect(queue_item.method_name).to eq "perf_capture_historical"
      q_start_time, q_end_time = queue_item.args
      expect(q_start_time).to be_within(0.00001).of expected_start_time
      expect(q_end_time).to be_within(0.00001).of expected_end_time
    end

    def verify_perf_capture_queue(last_perf_capture_on, total_queue_items)
      Timecop.freeze do
        vm.last_perf_capture_on = last_perf_capture_on
        ems.perf_capture_object.queue_captures([vm], vm => {:interval => "realtime"})
        expect(MiqQueue.count).to eq total_queue_items

        # make sure the queue items are in the correct order
        queue_items = MiqQueue.order(:id).to_a

        # first queue item is realtime and only has a start time
        realtime_cut_off = 4.hours.ago.utc.beginning_of_day
        realtime_start_time = realtime_cut_off if last_perf_capture_on.nil? || last_perf_capture_on < realtime_cut_off
        verify_realtime_queue_item(queue_items.shift, realtime_start_time)

        # rest of the queue items should be historical
        if queue_items.any? && realtime_start_time
          interval_start_time = vm.last_perf_capture_on
          interval_end_time   = interval_start_time + 1.day
          queue_items.reverse_each do |q_item|
            verify_historical_queue_item(q_item, interval_start_time, interval_end_time)

            interval_start_time = interval_end_time
            interval_end_time  += 1.day # if collection threshold is parameterized, this increment should change
            interval_end_time   = realtime_start_time if interval_end_time > realtime_start_time
          end
        end
      end
    end

    it "when last_perf_capture_on is nil (first time)" do
      stub_performance_settings(:history => {:initial_capture_days => nil})
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        verify_perf_capture_queue(nil, 1)
        Timecop.travel(20.minutes)
        verify_perf_capture_queue(nil, 1)
      end
    end

    it "when last_perf_capture_on is very old (older than the realtime_cut_off of 4.hours.ago)" do
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        verify_perf_capture_queue((10.days + 5.hours + 23.minutes).ago, 11)
      end
    end

    it "when last_perf_capture_on is recent (before the realtime_cut_off of 4.hours.ago)" do
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        verify_perf_capture_queue((0.days + 2.hours + 5.minutes).ago, 1)
      end
    end

    it "is able to handle multiple attempts to queue perf_captures and not add new items" do
      MiqQueue.delete_all
      Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
        last_perf_capture_on = (10.days + 5.hours + 23.minutes).ago
        verify_perf_capture_queue(last_perf_capture_on, 11)
        Timecop.travel(20.minutes)
        verify_perf_capture_queue(last_perf_capture_on, 11)
      end
    end

    it "links supplied miq_task with queued item which allow to initialize MiqTask#started_on attribute" do
      MiqQueue.delete_all
      task = FactoryBot.create(:miq_task)
      ems.perf_capture_object.queue_captures([vm], vm => {:interval => "realtime", :task_id => task.id})
      expect(MiqQueue.first.miq_task_id).to eq task.id
    end
  end

  describe "#perf_capture_queue('historical')" do
    let!(:ems) { FactoryBot.create(:ems_openstack, :zone => miq_server.zone) }
    let(:vm) { FactoryBot.create(:vm_perf_openstack, :ext_management_system => ems) }

    context "with capture days > 0 and multiple attempts" do
      def verify_perf_capture_queue_historical(last_perf_capture_on, total_queue_items)
        vm.last_perf_capture_on = last_perf_capture_on
        ems.perf_capture_object.queue_captures([vm], vm => {:interval => "historical"})
        expect(MiqQueue.count).to eq total_queue_items
      end

      it "when last_perf_capture_on is nil(first time)" do
        stub_performance_settings(:history => {:initial_capture_days => 7})
        MiqQueue.delete_all
        Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
          verify_perf_capture_queue_historical(nil, 8)
          Timecop.travel(20.minutes)
          verify_perf_capture_queue_historical(nil, 8)
        end
      end

      it "when last_perf_capture_on is very old" do
        stub_performance_settings(:history => {:initial_capture_days => 7})
        MiqQueue.delete_all
        Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
          last_capture_on = (10.days + 5.hours + 23.minutes).ago
          verify_perf_capture_queue_historical(last_capture_on, 8)
          Timecop.travel(20.minutes)
          verify_perf_capture_queue_historical(last_capture_on, 8)
        end
      end

      it "when last_perf_capture_on is fairly recent" do
        stub_performance_settings(:history => {:initial_capture_days => 7})
        MiqQueue.delete_all
        Timecop.freeze(Time.now.utc.end_of_day - 6.hours) do
          last_capture_on = (10.days + 5.hours + 23.minutes).ago
          verify_perf_capture_queue_historical(last_capture_on, 8)
          Timecop.travel(20.minutes)
          verify_perf_capture_queue_historical(last_capture_on, 8)
        end
      end
    end
  end
end
